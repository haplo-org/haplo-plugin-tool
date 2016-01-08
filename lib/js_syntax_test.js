/* Haplo Plugin Tool             http://docs.haplo.org/dev/tool/plugin
 * (c) Haplo Services Ltd 2006 - 2016    http://www.haplo-services.com
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.         */


(function() {
    var root = this;

    // Options for the syntax checking

    var opts = function() {
        return {
            asi: false,
            bitwise: false,
            boss: false,
            curly: true,
            debug: false,
            devel: false,
            eqeqeq: false,
            evil: false,
            forin: false,
            immed: false,
            laxbreak: false,
            newcap: true,
            noarg: true,
            noempty: false,
            nonew: true,
            nomen: false,
            onevar: false,
            plusplus: false,
            regexp: false,
            undef: true,
            sub: true,
            strict: false,
            white: false
        };
    };

    // Options
    var optionsServer = opts();
    var optionsBrowser = opts();
    optionsBrowser.browser = true;

    // Predefined globals
    var globalsServer = [
        'O',
        'SCHEMA', 'TYPE', 'ATTR', 'ALIASED_ATTR', 'QUAL', 'LABEL', 'GROUP',
        'HTTP', 'DBTime',
        'console', 'JSON',
        '_', 'Handlebars', 'oForms', 'moment', 'XDate'
    ];
    var globalsBrowser = ['Haplo', 'ONEIS', 'jQuery', '_'];
    var globalsTest = globalsServer.concat('T');

    // Set globals
    root.syntax_tester_globals = function(string) {
        globals = eval("("+string+")");
    };

    // Syntax tester function
    root.syntax_tester = function(source, kind, extraGlobals) {
        var globalList;
        switch(kind) {
            case "js":      globalList = globalsServer;    break;
            case "static":  globalList = globalsBrowser;   break;
            case "test":    globalList = globalsTest;      break;
        }
        if(!globalList) { return "Wrong kind of file"; }
        var globals = {}, addGlobal = function(g) { globals[g] = false; };
        globalList.forEach(addGlobal);
        if(extraGlobals) {
            JSON.parse(extraGlobals).forEach(addGlobal);
        }
        var result = JSHINT(source,
            (kind !== 'static') ? optionsServer : optionsBrowser,
            globals
        );
        if(result == true) { return null; } // success
        // Errors - compile a report, can't use the default one as it's HTML
        var data = JSHINT.data();
        var errors = data.errors;
        var report = '';
        for(var e = 0; e < errors.length; e++) {
            var err = errors[e];
            if(err !== null && err !== undefined) { // oddly it will do that
                report += "line "+err.line+": "+err.reason+"\n    "+err.evidence+"\n";
            }
        }
        return (report == '') ? null : report;
    };

})();
