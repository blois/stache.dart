// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dom_mustache;

import 'dart:html';
import 'package:dom_mustache/src/template.dart';
import 'package:safe_dom/validators.dart';
import 'package:safe_dom/parser.dart' as parser;

abstract class Template {
  factory Template.fromHtml(String html,
      {Element context, NodeValidator validator}) {
    if (validator == null) {
      validator = new NodeValidator();
    }
    if (context == null) {
      context = document.body;
    }

    var fragment = parser.createFragment(context, html, validator: validator);
    return new Template.fromFragment(fragment, validator: validator);
  }

  factory Template.fromFragment(DocumentFragment fragment,
      {NodeValidator validator}) {
    if (validator == null) {
      validator = new NodeValidator();
    }

    return new TemplateImpl(fragment, validator);
  }
  DocumentFragment render(Map data, {Map<String, Template> partials});
}
