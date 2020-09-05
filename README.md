# js2uml
command-line tool for generating UML class diagrams from JS source

adapted from [js2uml](https://github.com/imfly/js2uml) (改编自 by [@imfly](https://github.com/imfly), Wechat: kubying 的 js2uml。翻译：[DeepL](https://www.deepl.com/translator#en/zh/Translation%20by%20DeepL))


## Description
js2uml has been developed using [PlantUML](https://plantuml.com), [Esprima](https://esprima.org), and [Graphviz](http://www.graphviz.org/) by [imfly](https://github.com/imfly).

This repository aims to maintain the project by adding compatibility. Perl scripts are introduced for preparing the input source before it is parsed using an abstract syntax tree. Nonetheless, the scripts use regular expressions that can be turned into Esprima calls.


## Clone Project
```
git clone https://github.com/escallic/js2uml
```


## Install Dependencies

```
cd js2uml && npm install
```


## Run with Example

```
bin/index.js -s test/dapps.js -o test/dapps.png
```


## View UML Example

```
firefox test/dapps.png
```
[Learn more.](https://developer.mozilla.org)


## Help
```
bin/index.js --help
```


## 协议（License)

MIT License
