# js2uml
command-line tool for generating UML class diagrams from JS source

Wrapper for [js2uml](https://github.com/imfly/js2uml) by [@imfly](https://github.com/imfly), Wechat: kubying. 翻译：[DeepL](https://www.deepl.com/translator#en/zh/Translation%20by%20DeepL))


## Description
js2uml has been developed using [PlantUML](https://plantuml.com), [Esprima](https://esprima.org), and [Graphviz](http://www.graphviz.org/) by [imfly](https://github.com/imfly).

This repository aims to add compatibility to the project. A Perl script is introduced for preparing the input source before it is parsed by Esprima. The script merely removes several aspects of the original utility that are incomplete. It does not specify any tests for where js2uml fails. Nonetheless, the script uses regular expressions that may be observed for building abstract syntax trees. 


## Clone this project.
```
git clone https://github.com/escallic/js2uml
```


## Clone another project for which you want to view the UML.
```
git clone https://github.com/openstreetmap/iD.git
```


## Install dependencies.
```
cd js2uml && npm install
```


## Run
```
cd ../iD
../js2uml/js2uml.pl ../js2uml/bin/index.js modules uml
```


## License

MIT License
