# Libre Method

This project produces place notation for bellringing methods in highly accessible JSON and CSV formats.

It works by downloading and processing XML methods data from the [Tony Smith's website](http://www.methods.org.uk).

# I just want the data!

To get a copy of the data (generated 2023-10-25), please visit the sister repo [libre-method-data-dump](https://github.com/alexhunsley/libre-method-data-dump).

# How to run the script

You will need:

* Bash
* Python3 and the `xmltodict` lib
* `jq` (easily installed with e.g. homebrew: `brew install jq`)

To run the script: 

```
> cd code/
> chmod u+x process.sh
> ./process.sh
```

Note that the script only downloads a copy of the methods XML from the webserver when it needs to: if the XML on the webserver hasn't changed since the last download, it isn't downloaded again.

# What do you mean by "Libre"?

In this case, it doesn't mean "free" as in money; it means "free" as in "convenient to download place notation in a few universal and common formats, and usable immediately for whatever project you had in mind".

# Motivation

Anyone wanting to write a blueline app or do research into methods needs a source of place notation and method information.

The XML data from [Tony Smith's website](http://www.methods.org.uk) is very detailed and structured, but it also presents you with a task you must do before you can get started on your project: parsing XML, and possibly marrying parts of it together (in particular, the `method` and `methodSet` fallback mechanism).

Sometimes all you want is a very flat source of data that lets you get on with your main task (even if that involves some repetition in the data).

That's what Libre Method aims to provide: flat structures (basically lists) of CSV and JSON method data, which includes well formed method names and place notation.

