import xmltodict
import json
import sys

#
# Libre Method by Alex Hunsley 2023
# https://github.com/alexhunsley/libre-method-data-dump
#

# GPT produced code for xml -> json while ensuring certain nodes are ALWAYS represented as 'attribute mode',
# i.e. a dict with keys #text (the main XML element value) and @attrib1, @attrib2 for the attributes when present.
# We must do this to any XML nodes that have attributes, so we end up with completely consistent json
# which we can fix up later using jq (by naming e.g. classification.#text as classification_text, i.e. a direct child value).
#
# From TS' XML description doc on methods: 
#
#   * A method's values fallback to the methodSet.properties values when not set, e.g. stage is picked up from method, if not there
#     we then look for `methodSet.properties.stage`.
#
#   * A methodSet and a method can have `classification`. Again, method is used for these values, then we fall back to methodSet for any missing.
#


def dictWithEmptyRemoved(d):
    return {k: v for k, v in d.items() if v}

def wrap_with_text(value):
    """Wraps string values with #text key."""
    if isinstance(value, str):
        return {"#text": value}
    return value

"""
Ensures that:
 * all nodes in tags_to_fix are represented as dicts with a #text node
 * any element mapping to None (null) is removed
"""
def ensure_text_dict(item, tags_to_fix):
    if isinstance(item, dict):
        if len(item) == 1:
            first_val = item[list(item.keys())[0]]

        for key, value in item.items():
            if key in tags_to_fix:
                if isinstance(value, list):
                    item[key] = [wrap_with_text(v) for v in value]
                else:
                    item[key] = wrap_with_text(value)
            else:
                item[key] = ensure_text_dict(value, tags_to_fix)

        # remove any nulls (which are the result of empty XML elements like <hello/>)
        return dictWithEmptyRemoved(item)
    elif isinstance(item, list):
        return [ensure_text_dict(i, tags_to_fix) for i in item]
    return item

xml_file = "allmeths.xml"

with open(xml_file, 'r') as file:
    data = xmltodict.parse(file.read(), force_list=('method'))
    data = ensure_text_dict(data, tags_to_fix="classification")
  
    result_json = json.dumps(data, indent=4)

    with open("methods_processed.json", "w") as text_file:
        text_file.write(result_json)

