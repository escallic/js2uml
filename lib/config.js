var moment = require('moment');
moment.locale('en-US');

module.exports = configure = {
    "comment": "Is this field correct", // locale en
    "notification": "✅ Config file saved at ",
    "browserOtherMsg": "UML output was generated at ${cwd}/${uml_dir}.",
    "locale": "en", // [https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes]
    "combineFiles": "y", // Are the classes in this project all in ?(the same:separate)! ?(file:files)!
    "title": "", // Is this the name of the project
    "header": "v1.0", // Is this the software version
    "hasLicense": "", // Is this software ?(:un)!protected by copyright
    "copyleft": "", // Is this software ?(:not)! free ?(and:or)! share-alike
    "author": "", // Is this the list of contributors to the software
    "timestamp": "", // Is this the timestamp code [https://momentjs.com/docs/#/parsing/string-format/]
    "footer": ".", // Is this the website or URI
    "borderColor": "#000000", // Is this the border color [https://www.computerhope.com/htmcolor.htm].
    "backgroundcolor": "#FFFFFF", // Is this the background color
    "sourceFile": "", // Is this the input path trace
    "output": "", // Is this the UML path trace
    "copyright": function() {
        if(moment.locale) moment.locale(configure.locale);
        var configureCopyleft = configure.copyleft ? " 🄯 " : " © ";
        var _configureCopyleft = " Public Domain" + configure.author|configure.timestamp|configure.footer ? " " : ", ";
        var configureFooter = configure.footer ? ", " : "";
        var configureHasLicense = configure.hasLicense ? configureCopyleft : _configureCopyleft;
        var configureTimestamp = configure.timestamp ? moment().format(configure.timestamp) + configureFooter : "";
        return configureHasLicense + configureTimestamp + configure.footer;
    }
}