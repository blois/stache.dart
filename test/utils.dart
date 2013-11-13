// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dom_mustache.test.utils;

import 'dart:html';
import 'package:unittest/unittest.dart';

void validate(Node a, Node b) {
  var aHtml = nodeToHtml(a);
  var bHtml = nodeToHtml(b);

  normalizeTextNodes(a);
  normalizeTextNodes(b);

  validateNodes(a, b);
}

void validateToHtml(dom, html) {
  var expectedDOM = parse(html);
  // Serialize then re-parse, to avoid some parsing differences of the expected.
  dom = parse(nodeToHtml(dom));
  validate(dom, expectedDOM);
}

String nodeToHtml(Node node) {
  var host = document.createElement('div');
  host.append(node.clone(true));
  return host.innerHtml;
}


/**
 * Validate that two DOM trees are equivalent.
 */
void validateNodes(Node a, Node b, [String path = '']) {
  path = '${path}${a.runtimeType}';
  expect(a.nodeType, b.nodeType, reason: '$path nodeTypes differ');
  if (a.nodeType == Node.TEXT_NODE) {
    expect(a.text.trim(), b.text.trim(), reason: '$path texts differ');
  }

  if (a is Element) {
    expect(a.localName, b.localName, reason: '$path localNames differ');
    expect(a.nodes.length, b.nodes.length,
        reason: '$path nodes.lengths differ');

    Element bE = b;
    expect(a.tagName, bE.tagName, reason: '$path tagNames differ');
    expect(a.attributes.length, bE.attributes.length,
        reason: '$path attributes.lengths differ');
    for (var key in a.attributes.keys) {
      expect(a.attributes[key], bE.attributes[key],
          reason: '$path attribute [$key] values differ');
    }
  }
  for (var i = 0; i < a.nodes.length; ++i) {
    validateNodes(a.nodes[i], b.nodes[i], '$path[$i].');
  }
}

/**
 * Combines adjacent text nodes.
 */
void normalizeTextNodes(Node node) {
  var currentText = null;

  for (var i = node.nodes.length - 1; i >= 0; --i) {
    var child = node.nodes[i];
    if (child is Text) {
      if (currentText == null) {
        currentText = child;
      } else {
        currentText.text = child.text + currentText.text;
        child.remove();
      }
    } else {
      if (currentText != null && currentText.text == '') {
        currentText.remove();
      }
      currentText = null;
    }
    if (child is Element) {
      normalizeTextNodes(child);
    }
  }
  if (currentText != null && currentText.text == '') {
    currentText.remove();
  }
}

DocumentFragment parse(String html) {
  var range = new Range();
  range.selectNode(document.body);

  return range.createContextualFragment(html);
}

void compare(String template, String expected, data) {
  var template = Template.fromHtml(template);
  var result = template.render(data);
  validate(result, parse(expected));
}


/**
 * Validator which accepts everything.
 */
class NullValidator implements NodeValidator {
  bool allowsElement(Element element) => true;
  bool allowsAttribute(Element element, String name, String value) => true;
}
