// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library stache;

import 'dart:html';
import 'package:stache/src/template.dart';

abstract class Template {
  factory Template.fromHtml(String html,
      {Element context, NodeValidator validator}) {
    if (validator == null) {
      validator = new NodeValidator();
    }
    if (context == null) {
      context = document.body;
    }

    var fragment = context.createFragment(html, validator: validator);
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
