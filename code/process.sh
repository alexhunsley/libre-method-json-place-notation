#!/bin/bash

#
# Libre Method by Alex Hunsley 2023
#

URL="http://www.methods.org.uk/method-collections/xml-zip-files/allmeths-xml.zip"
OUTPUT_FILE="allmeths-xml.zip"

# curl -z flag doesn't re-download it if the local file has same date as server file
HTTP_STATUS=$(curl -z "$OUTPUT_FILE" -O -w "%{http_code}" "$URL")

generated_data_dir="generated_data"

methods_processed="methods_processed.json"
methods_processed_non_false="methods_processed_non_false.json"

# uncomment this line to force processing even if the xml zip hasn't changed omn webserver
# force_processing_even_if_xml_unchanged=y

# is there newer data on the website?
if  [ ! "$force_processing_even_if_xml_unchanged" ] && [ "$HTTP_STATUS" == "304" ]; then

    echo
    echo
    echo "${OUTPUT_FILE} was not modified on the server since the last download, so I'm stopping."
    echo
    echo
    exit 0
fi


# we always delete the old generated data dir before generating it all again
if [ -d "${generated_data_dir}" ]; then
	rm -rf "${generated_data_dir}"
fi


mkdir -p "${generated_data_dir}"
unzip -o "$OUTPUT_FILE"

echo
echo
echo "Converting the XML to JSON..."

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

	##############################################
	# full data export
	
	jq --arg stg "$stage" '[
	  .collection.methodSet[] |
	  select($stg == "all" or .properties.stage == $stg) |
      .properties as $methodSetProperties |
	  .method[] |
	  { 
  	    "id": (.["@id"] // $methodSetProperties["@id"]), 
	    "name": (.name // $methodSetProperties.name), 
	    "title": (.title // $methodSetProperties.title), 
	    "notation": (.notation // $methodSetProperties.notation),
	    "lengthOfLead": (.lengthOfLead // $methodSetProperties.lengthOfLead),
	    "numberOfHunts": (.numberOfHunts // $methodSetProperties.numberOfHunts),
	    "huntbellPath": (.huntbellPath // $methodSetProperties.huntbellPath), 
	    "leadHeadCode": (.leadHeadCode // $methodSetProperties.leadHeadCode),
	    "leadHead": (.leadHead // $methodSetProperties.leadHead),
	    "stage": (.stage // $methodSetProperties.stage),
	    "symmetry": (.symmetry // $methodSetProperties.symmetry),
	    "classification_text": .classification."#text",
	    "classification_little": .classification."@little",
	    "classification_differential": .classification."@differential",
	    "classification_plain": .classification."@plain"
	  } | with_entries(select(.value != null))
	  ]' ${methods_processed_non_false} > ${non_false_filename}

	# json to CSV
	jq -r '(map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv' ${non_false_filename} > ${non_false_csv_filename}

	##############################################
	# simple data export (only crucial fields)
	jq --arg stg "$stage" '[
	  .collection.methodSet[] |
	  select($stg == "all" or .properties.stage == $stg) |
      .properties as $methodSetProperties |
	  .method[] |
	  { 
	    "name": (.name // $methodSetProperties.name), 
	    "title": (.title // $methodSetProperties.title), 
	    "notation": (.notation // $methodSetProperties.notation),
	    "stage": (.stage // $methodSetProperties.stage)
	  } | with_entries(select(.value != null))
	  ]' ${methods_processed_non_false} > ${simple_non_false_filename}

	# json to CSV
	jq -r '(map(keys) | add | unique) as $cols | map(. as $row | $cols | map($row[.])) as $rows | $cols, $rows[] | @csv' ${simple_non_false_filename} > ${simple_non_false_csv_filename}

done

echo
echo
echo Finished.
echo

