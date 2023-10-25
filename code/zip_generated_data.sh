#!/bin/bash

# zip_generated_data.sh
# Alex Hunsley
#

generated_data_dir="generated_data"
generated_data_zipped_dir="generated_data_zipped"

if [ -d "${generated_data_zipped_dir}" ]; then
	echo "Deleting original dir..."
	rm -rf "${generated_data_zipped_dir}"
fi

mkdir -p "${generated_data_zipped_dir}"

cp readme.txt ${generated_data_dir}

pushd "${generated_data_dir}"
pwd
ls readme.txt

for file in *.csv *.json
do
	echo "Zipping $file"

	basenoid=$(basename $file)

	# We don't store the folder structure.
	# Something like Mac OS will still create the folder if you unzip it using finder, note!
	zip ../${generated_data_zipped_dir}/${basenoid}.zip ${basenoid} readme.txt
done
