#!/bin/bash

#
# Libre Method by Alex Hunsley 2023
# https://github.com/alexhunsley/libre-method-json-place-notation
#


working_files_dir="working_files"
cached_files_dir="cached_files"

working_dir_file_path() {
    
    local filename="$1"
    
    echo "${working_files_dir%/}/${filename}"
}

cached_dir_file_path() {
    
    local filename="$1"
    
    echo "${cached_files_dir%/}/${filename}"
}

if [ ! -d ${cached_files_dir} ]; then
	mkdir -p "${cached_files_dir}"
fi

generated_data_dir="generated_data"

URL="http://www.methods.org.uk/method-collections/xml-zip-files/allmeths-xml.zip"

ZIP_FILE=$(cached_dir_file_path "allmeths-xml.zip")
UNZIPPED_FILE_DIR="${cached_files_dir}"
UNZIPPED_FILE=$(cached_dir_file_path "allmeths.xml")

echo "UNZIPPED_FILE: ${UNZIPPED_FILE}"

# curl -z flag doesn't re-download it if the local file has same date as server file
HTTP_STATUS=$(curl -z "$ZIP_FILE" -o "$ZIP_FILE" -w "%{http_code}" "$URL")

methods_processed=$(working_dir_file_path "methods_processed.json")
methods_processed_non_false=$(working_dir_file_path "methods_processed_non_false.json")

# uncomment this line to force processing even if the xml zip hasn't changed on webserver
# force_processing_even_if_xml_unchanged=y

# do we already have the latest zip?
if [ "$HTTP_STATUS" == "304" ]; then
	
	if [ ! "$force_processing_even_if_xml_unchanged" ]; then
	    echo
	    echo
	    echo "${ZIP_FILE} was not modified on the server since the last download, so I'm stopping."
	    echo
	    echo "If you want to force processing again regardless, please uncomment this line in the script:"
	    echo 
	    echo "    # force_processing_even_if_xml_unchanged=y"
	    echo
	    echo "(Doing so will not re-download the XML zip file unless you first delete allmeths-xml.zip locally.)"
	    echo
	    echo
	    exit 0
	else
		# don't exit early if we want to forcing re-processing
	    echo
	    echo
	    echo "${ZIP_FILE} was not modified on the server since the last download, but the flag"
	    echo "'force_processing_even_if_xml_unchanged' is enabled, so I will process the previously downloaded data..."
	    echo
	    echo
	fi
fi

if [ -d ${working_files_dir} ]; then
	rm -rf "${working_files_dir}"
fi
mkdir -p "${working_files_dir}"

# in force mode, we tend to assume the unzipped file contents are still there, but if not, we unzip again.
if [ ! -f "$UNZIPPED_FILE" ] || [ ! "$force_processing_even_if_xml_unchanged" ]; then
	echo
	echo "Unzipping ${ZIP_FILE}:"
	echo
	unzip -o "${ZIP_FILE}" -d "${UNZIPPED_FILE_DIR}"
	echo
	echo
fi

# we always delete the old generated data dir before generating it all again
if [ -d "${generated_data_dir}" ]; then
	rm -rf "${generated_data_dir}"
fi

mkdir -p "${generated_data_dir}"

echo
echo
echo "Converting the XML to JSON..."

# Could pass in ${UNZIPPED_FILE} filename to the script here. In another life maybe.
python convertXMLtoJSON.py > ${methods_processed}

# We filter out false methods.
# If you want to keep false methods, replace the below line with "mv ${methods_processed} ${methods_processed_non_false}".
jq '.collection.methodSet |= map(select(.notes | contains("False") | not))' ${methods_processed} > ${methods_processed_non_false}

echo
echo

all_found_stages=$(jq '.collection.methodSet[].properties.stage' ${methods_processed_non_false} | tr -d '\"' | sort | uniq | sort -n | tr '\n' ' ')

echo "Found stages: ${all_found_stages}"
echo

all_stages="all"

for stage in ${all_found_stages} ${all_stages}
do
	echo
	echo "Processing stage" ${stage}

	if [[ "$stage" == "${all_stages}" ]]; then
		stage_padded="${all_stages}"
	else
		stage_padded=$(printf "%02d" $stage)
	fi

	non_false_filename=${generated_data_dir}/stage-${stage_padded}.json
	non_false_csv_filename=${generated_data_dir}/stage-${stage_padded}.csv

	simple_non_false_filename=${generated_data_dir}/simple-stage-${stage_padded}.json
	simple_non_false_csv_filename=${generated_data_dir}/simple-stage-${stage_padded}.csv

	# any supplement
	supplement_path="../../libre-method-supplement/supplement.json"
	simple_supplement_path="../../libre-method-supplement/simple_supplement.json"

	supplement_json_content="[]"
	simple_supplement_json_content="[]"

	if [ "$stage" == "8" ]; then
		if [ -f ${supplement_path} ]; then
			supplement_json_content=`cat ${supplement_path}`
		fi

		if [ -f ${simple_supplement_path} ]; then
			simple_supplement_json_content=`cat ${simple_supplement_path}`
		fi
	fi

	##############################################
	# full data export
	jq --arg stg "$stage" --argjson supplement_json "$supplement_json_content" '[
	  .collection.methodSet[] |
	  select($stg == "all" or .properties.stage == $stg)
      .properties as $methodSetProperties |
	  .method[] | { 
  	    "id": (.["@id"] // $methodSetProperties["@id"]), 
	    "stage": (.stage // $methodSetProperties.stage),
	    "name": (.name // $methodSetProperties.name), 
	    "title": (.title // $methodSetProperties.title), 
	    "notation": (.notation // $methodSetProperties.notation),
	    "leadHead": (.leadHead // $methodSetProperties.leadHead),
	    "leadHeadCode": (.leadHeadCode // $methodSetProperties.leadHeadCode),
	    "lengthOfLead": (.lengthOfLead // $methodSetProperties.lengthOfLead),
	    "symmetry": (.symmetry // $methodSetProperties.symmetry),
	    "numberOfHunts": (.numberOfHunts // $methodSetProperties.numberOfHunts),
	    "huntbellPath": (.huntbellPath // $methodSetProperties.huntbellPath), 
	    "classification_text": .classification."#text",
	    "classification_little": .classification."@little",
	    "classification_differential": .classification."@differential",
	    "classification_plain": .classification."@plain"
	  } |
	  with_entries(select(.value != null))
	  ] + $supplement_json' ${methods_processed_non_false} > ${non_false_filename}

	# json to CSV
	# we have a set order for the CSV data columns, in order to add any new columns in an orderly fashion in future.
	jq -r '[
		"id", "stage", "name", "title", "notation", "leadHead", "leadHeadCode", "lengthOfLead", "symmetry", "numberOfHunts", "huntbellPath", "classification_text", "classification_little", "classification_differential", "classification_plain"] as $cols |
	 	map(. as $row | $cols | map($row[.])) as $rows |
	 	$cols, $rows[] |
	 	@csv' ${non_false_filename} > ${non_false_csv_filename}

	##############################################
	# simple data export (only crucial fields)
	jq --arg stg "$stage" --argjson simple_supplement_json "$simple_supplement_json_content" '[
	  .collection.methodSet[] |
	  select($stg == "all" or .properties.stage == $stg) |
      .properties as $methodSetProperties |
	  .method[] |
	  { 
  	    "id": (.["@id"] // $methodSetProperties["@id"]),
	    "stage": (.stage // $methodSetProperties.stage),
	    "name": (.name // $methodSetProperties.name), 
	    "title": (.title // $methodSetProperties.title), 
	    "notation": (.notation // $methodSetProperties.notation),
	  } | with_entries(select(.value != null))
	  ] + $simple_supplement_json' ${methods_processed_non_false} > ${simple_non_false_filename}

	# json to CSV
	# we have a set order for the CSV data columns, in order to add any new columns in an orderly fashion in future.
	# The position of items here must match the same items in the non-simple CSV generation further above.
	jq -r '[
		"id", "stage", "name", "title", "notation"] as $cols |
	 	map(. as $row | $cols | map($row[.])) as $rows |
	 	$cols, $rows[] |
	 	@csv' ${simple_non_false_filename} > ${simple_non_false_csv_filename}

done

rm -rf "${working_files_dir}"

echo
echo
echo "Finished."
echo
echo

