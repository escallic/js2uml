# js2uml
A command-line tool that produces a UML class diagrams folder for an entire JavaScript project. [js2uml](https://github.com/imfly/js2uml) by [@imfly](https://github.com/imfly).


## Description
js2uml has been developed using [PlantUML](https://plantuml.com), [Esprima](https://esprima.org), and [Graphviz](http://www.graphviz.org/).

This fork preprocesses the source input for incompatible test cases before it generates abstract syntax trees.


## Clone this project:
```
git clone https://github.com/escallic/js2uml
```


## Clone another project for which you want to view the UML. For a good example:
```
git clone --depth=1 https://github.com/openstreetmap/iD.git
```


## Install dependencies:
```
cd js2uml && npm install
```


## Run:
```
cd ../iD
../js2uml/js2uml.pl ../js2uml/bin/index.js modules uml
```
