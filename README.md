## Haplo Plugin Tool

The Haplo Plugin Tool helps developers to write and deploy plugins for the [Haplo Platform](http://haplo.org).

For more information please see the main [Haplo web site](http://haplo.org) and the [Plugin Tool documentation](http://docs.haplo.org/dev/tool/plugin).


### Get dependencies

Run the `fetch_rhino.sh` script.

Run the `build_haplo_templates.sh` with the location of a Haplo platform checkout as the first argument. You will need a Java 8 `javac` on your `PATH`.


### Run from checkout

`jruby bin/haplo-plugin <arguments>`

The Plugin Tool requires JRuby so it can use some Java libraries.


### Release as gem

Run `jruby make_distribution.rb` and publish the resulting gem. Note you must use JRuby.


### Copyright and License

Haplo Plugin Tool is copyright [Haplo Services Ltd](http://www.haplo-services.com). See the COPYRIGHT file for full details.

Haplo Plugin Tool is licensed under the Mozilla Public License Version 2.0. See the LICENSE file for full details.

Distributions contain a copy of the [Rhino JavaScript Interpreter](http://www.mozilla.org/rhino/), licensed under the Mozilla Public License.

This repository and distributions contain a copy of [JSHint](http://jshint.com/), licensed under a modified MIT license that prohibits use for Evil. See lib/jshint.js for details.

This repository and distributions contain a copy of [UglifyJS](https://github.com/mishoo/UglifyJS), licensed under the BSD license.
