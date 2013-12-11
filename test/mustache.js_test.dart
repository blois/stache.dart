// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js_tests;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:html';
import 'dart:js' as js;

import 'package:stache/stache.dart';
import 'package:mocha_style_test/mocha.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';

var testNames = [
  "ampersand_escape",
  "apostrophe",
  "array_of_strings",
  "backslashes",
  "bug_11_eating_whitespace",
  //"changing_delimiters", // no support for delimiters
  "check_falsy",
  "comments",
  //"complex", // Binding of the 'this' in the callback
  "context_lookup",
  //"delimiters", // no support for changing delimiters
  "disappearing_whitespace",
  "dot_notation",
  "double_render",
  "empty_list",
  "empty_sections",
  "empty_string",
  "empty_template",
  "error_not_found",
  "escaped",
  "falsy",
  "grandparent_context",
  //"higher_order_sections", // no support for custom renderers
  "included_tag",
  "inverted_section",
  "keys_with_questionmarks",
  //"malicious_template",
  "multiline_comment",
  "nested_dot",
  //"nested_higher_order_sections", // no support for custom renderers
  "nested_iterating",
  "nesting",
  "nesting_same_name",
  "null_string",
  "null_view",
  "partial_array",
  "partial_array_of_partials_implicit",
  "partial_array_of_partials",
  "partial_empty",
  "partial_template",
  "partial_view",
  "partial_whitespace",
  "recursion_with_same_names",
  "reuse_of_enumerables",
  "section_as_context",
  "simple",
  "string_as_context",
  "two_in_a_row",
  "two_sections",
  "unescaped",
  "whitespace",
  "zero_view"
];

main() {
  for (var name in testNames) {
    test(name, () {
      return loadTest(name).then((data) {
        var template = new Template.fromHtml(data['mustache']);
        var partials = {};
        if (data['partial'] != null) {
          partials['partial'] = new Template.fromHtml(data['partial']);
        }
        var result = template.render(data['js'], partials);
        validateToHtml(result, data['text']);
      });
    });

  }
}

Future<Map> loadTest(String name) {
  var completer = new Completer<Map>();
  var data = {};

  var requests = [];

  requests.add(HttpRequest.getString('base/test/_files/$name.js').then((text) {
    data['js'] = eval(text);
  }));

  requests.add(HttpRequest.getString('base/test/_files/$name.mustache').then((text) {
    data['mustache'] = text;
  }));

  requests.add(HttpRequest.getString('base/test/_files/$name.txt').then((text) {
    data['text'] = text;
  }));

  if (name.startsWith('partial_')) {
    requests.add(HttpRequest.getString('base/test/_files/$name.partial').then((text) {
      data['partial'] = text;
    }));
  }

  return Future.wait(requests).then((_) {
    return data;
  });
}

int id = 0;
eval(String text) {
  var dataId = '__id${id++}';
  text = 'window.$dataId = $text';
  document.body.append(new ScriptElement()..text = text);

  return wrapJsObjectIfNeeded(js.context[dataId]);
}

/**
 * Wraps JS objects into Dart types to make all JS object act as maps in
 * Dart.
 */
wrapJsObjectIfNeeded(obj) {
  if (obj is js.JsArray) {
    return new JsArrayList(obj);
  } else if (obj is js.JsFunction) {
    return () {
      return obj.apply([]);
    };
  } else if (obj is js.JsObject) {
    return new JsObjectMap(obj);
  }
  return obj;
}

/**
 * Minimal support needed to expose JS objects as maps to Dart
 */
class JsObjectMap implements Map<String, dynamic> {
  final js.JsObject _object;
  JsObjectMap(this._object);

  operator [](Object key) {
    return wrapJsObjectIfNeeded(_object[key]);
  }
}

/**
 * Minimal support needed to ensure items get wrapped if needed.
 */
class JsArrayList extends Object with ListMixin {
  final js.JsArray _array;
  JsArrayList(this._array);

  operator [](index) {
    return wrapJsObjectIfNeeded(_array[index]);
  }

  int get length => _array.length;
}


