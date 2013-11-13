// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library js_tests;

import 'dart:async';
import 'dart:html';

import 'package:stache/stache.dart';
import 'package:stache/src/template.dart';
import 'package:unittest/html_config.dart';
import 'package:unittest/unittest.dart';

import 'utils.dart';

main() {
  useHtmlConfiguration();

  var noValidation = new NullValidator();

  test('no bindings', () {
    var fragment = parse('<div><span></span></div>');
    var template = new TemplateImpl(fragment, noValidation);

    expect(template.root.fragment, fragment);
    expect(template.root.renderers.length, 0);
  });

  test('text binding', () {
    var fragment = parse('<div>{{content}}</div>');

    var template = new TemplateImpl(fragment, noValidation);
    var root = template.root;

    expect(root.fragment, fragment);
    expect(root.staticRenderers.length, 1);

    TextBindingRenderer binding = template.root.staticRenderers.single;
    expect(binding is TextBindingRenderer, isTrue);

    var result = template.render({'content': 'result'});

    validate(result, parse('<div>result</div>'));
  });

  test('bindings interspersed', () {
    var fragment = parse('<div>{{content}}<span></span>{{content}}</div>');
    var template = new TemplateImpl(fragment, noValidation);

    expect(template.root.staticRenderers.length, 2);

    var result = template.render({'content': 'result'});

    validate(result, parse('<div>result<span></span>result</div>'));
  });

  test('list simple', () {
    var fragment = parse('<div>{{#items}}<span></span>{{/items}}</div>');
    var template = new TemplateImpl(fragment, noValidation);
    var root = template.root;

    expect(root.renderers.length, 1);
    // div contents should move into the section.
    //expect(root.fragment.nodes[0].nodes.length, 0);

    FragmentRenderer list = template.root.renderers.single;
    expect(list.fragment.nodes.length, 1);

    var result = template.render({'items': [0, 1]});
    validate(result, parse('<div><span></span><span></span></div>'));
  });

  test('list items', () {
    var fragment = parse('<div>{{#items}}<span>{{.}}</span>{{/items}}</div>');
    var template = new TemplateImpl(fragment, noValidation);

    FragmentRenderer list = template.root.renderers.single;
    var binding = list.staticRenderers.single;
    // Binding path is relative to list's content.
    //expect(binding.insertionPath.path, [0, 0]);

    var result = template.render({'items': [1, 2]});
    validate(result, parse('<div><span>1</span><span>2</span></div>'));
  });

  test('offset list', () {
    var fragment =
        parse('<div><ul></ul>{{#items}}<span>{{.}}</span>{{/items}}</div>');

    var template = new TemplateImpl(fragment, noValidation);
    var result = template.render({'items': [1]});
    validate(result, parse('<div><ul></ul><span>1</span></div>'));
  });

  test('null list', () {
    var fragment = parse('<div>{{#items}}<span>{{.}}</span>{{/items}}</div>');

    var template = new TemplateImpl(fragment, noValidation);
    var result = template.render({'items': null});
    validate(result, parse('<div></div>'));
  });

  test('nested list', () {
    var fragment =
        parse('<div>{{#items}}{{#items}}{{.}}x{{/items}}y{{/items}}</div>');
    var template = new TemplateImpl(fragment, noValidation);

    FragmentRenderer level1 = template.root.renderers.single;
    var level2 = level1.renderers.first;
    expect(level2.insertionPath.path, [0]);

    var result = template.render({
      'items': [
        {'items': [1, 2]},
        {'items': [3, 4]},
      ]});

    expect(result.nodes[0].text, '1x2xy3x4xy');
  });

  test('conditional', () {
    var fragment = parse('<div>{{^content}}foo{{/content}}</div>');
    var template = new TemplateImpl(fragment, noValidation);

    var result = template.render({});
    validate(result, parse('<div>foo</div>'));

    result = template.render({'content': {}});
    validate(result, parse('<div></div>'));
  });

  test('text interspersed', () {
    var fragment = parse('<div>{{content}}text{{content2}}</div>');
    var template = new TemplateImpl(fragment, noValidation);
    var result = template.render({
      'content': '1',
      'content2': '2',
    });
    var contents = result.nodes[0];
    expect(contents.nodes.length, 3);
    expect(contents.nodes[0].text, '1');
    expect(contents.nodes[1].text, 'text');
    expect(contents.nodes[2].text, '2');
  });

  test('empty attributes', () {
    var fragment = parse('<div class="foo"></div>');
    var template = new TemplateImpl(fragment, noValidation);
    var root = template.root;

    // No bindings.
    expect(root.renderers.length, 0);

    var result = template.render({});
    validate(result, parse('<div class="foo"></div>'));
  });

  test('simple binding', () {
    var fragment = parse('<div class="{{content}}"></div>');
    var template = new TemplateImpl(fragment, noValidation);
    var root = template.root;

    expect(root.renderers.length, 1);

    var result = template.render({'content': 'klass'});
    validate(result, parse('<div class="klass"></div>'));
  });

  test('partials', () {
    var partial = new Template.fromHtml('<span>{{content}}</span>');

    var template = new Template.fromHtml('<div>{{>partial}}</div>');

    var result = template.render({'content': 'foo'}, {'partial': partial});
    validate(result, parse('<div><span>foo</span></div>'));
  });
/*
  test('bad attrs', () {
    var template = new Template.fromFragment(
        parse('<img onerror="{{content}}" onload="foo"/>'));

    var result = template.render({'content': 'something'});
    validate(result, parse('<img onload="foo"/>'));
  });

  test('bad uris', () {
    var template = new Template.fromHtml('<img src="{{content}}"/>');

    var result = template.render({'content': 'javascript:alert("hola!")'});
    validate(result, parse('<img/>'));

    result = template.render({'content': 'foo.jpg'});
    validate(result, parse('<img src="foo.jpg"/>'));

    template = new Template.fromHtml('<img src="{{name}}{{extension}}"/>');
    result = template.render({
        'name': 'foo',
        'extension': '.jpg'});
    validate(result, parse('<img src="foo.jpg"/>'));

    result = template.render({
        'name': 'java',
        'extension': 'script:alert("hola!")'});
    validate(result, parse('<img/>'));
  });

  test('bad nesting', () {
    expect(() {
      new Template.fromHtml('<div>{{#items}}a{{.}}</div>b{{/items}}');
    }, throwsStateError);
  });
*/
  test('sections', () {
    var template = new Template.fromHtml('<span>{{#foo}}bar{{/foo}}</span>');
    var result = template.render({'foo': true});
    validate(result, parse('<span>bar</span>'));

    result = template.render({'foo': false});
    validate(result, parse('<span></span>'));

    result = template.render({'foo': null});
    validate(result, parse('<span></span>'));

    result = template.render({});
    validate(result, parse('<span></span>'));

    template = new Template.fromHtml('<span>{{#foo}}{{.}}{{/foo}}</span>');
    result = template.render({'foo': true});
    validate(result, parse('<span>true</span>'));
  });

  test('comments', () {
    var template = new Template.fromHtml('<span>{{!ignored}}</span>');
    var result = template.render({'ignored': true});
    validate(result, parse('<span></span>'));
  });
}
