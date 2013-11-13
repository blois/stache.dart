// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library stache.src.template;

import 'dart:html';
import 'package:stache/stache.dart';

class TemplateImpl implements Template {
  final FragmentRenderer _root;

  TemplateImpl(DocumentFragment fragment, NodeValidator validator):
    _root = new FragmentRenderer(fragment, null, null)
  {
    var stack = <FragmentRenderer>[];
    stack.add(_root);

    _processNode(fragment, stack, validator);
  }

  DocumentFragment render(Map data, [Map<String, Template> partials]) {
    var partialRenderers;
    if (partials != null) {
      partialRenderers = {};
      partials.forEach((key, value) {
        partialRenderers[key] = value.root;
      });
    }
    return _root.expand(new Context(data, null), partialRenderers);
  }

  FragmentRenderer get root => _root;

  void _processNode(Node node, List<FragmentRenderer> stack,
      NodeValidator validator) {
    var detaching = 0;

    for (var child in node.nodes.toList()) {
      // Text node.
      if (child.nodeType == Node.TEXT_NODE) {
        var tokens = _parseMustacheDirectives(child.text);
        for (var token in tokens) {
          var proxy = new Text('');
          if (detaching > 0) {
            stack.last.fragment.append(proxy);
          } else {
            node.insertBefore(proxy, child);
          }
          if (token.type == Directive.TEXT) {
            proxy.text = token.value;
            continue;
          } else if (token.type == Directive.END_SECTION) {
            if (stack.last.binding != token.value) {
              throw new StateError('Mismatched values');
            }
            stack.removeLast();
            proxy.remove();
            --detaching;
          } else {
            var renderer = token.toRenderer(proxy);
            if (renderer != null) {
              stack.last.addRenderer(renderer);

              if (renderer is FragmentRenderer) {
                stack.add(renderer);
                ++detaching;
              }
            }
          }
        }
        if (!tokens.isEmpty) {
          // Remove it since we're handling it with tokens.
          child.remove();
          continue;
        }
      }

      if (detaching > 0) {
        stack.last.fragment.append(child);
      }

      if (child is Element) {
        _processAttributes(child, stack, validator);
      }
      _processNode(child, stack, validator);
    }
    if (detaching == true) {
      throw new StateError('Mismatched sections and close tags');
    }
  }

  void _processAttributes(
      Element element, List<FragmentRenderer> stack, NodeValidator validator) {

    element.attributes.forEach((key, value) {
      var directives = _parseMustacheDirectives(value);
      if (!directives.isEmpty) {
        var attr = new AttributeRenderer(
            new NodePath(element), key, directives, validator);
        stack.last.renderers.add(attr);
      }
    });
  }

  // Cribbed unceremoniously from:
  // https://github.com/toolkitchen/mdv/blob/stable/src/template_element.js
  List<Directive> _parseMustacheDirectives(String s) {
    var result = <Directive>[];
    var index = 0, lastIndex = 0;
    while (lastIndex < s.length) {
      index = s.indexOf('{{', lastIndex);
      if (index < 0) {
        // If it's just text, then add nothing.
        if (lastIndex > 0) {
          result.add(new Directive(Directive.TEXT, s.substring(lastIndex)));
        }
        break;
      } else {
        // There is a non-empty text run before the next path token.
        if (index > 0 && lastIndex < index) {
          result.add(
              new Directive(Directive.TEXT, s.substring(lastIndex, index)));
        }
        lastIndex = index + 2;
        if (s.indexOf('{', lastIndex) == lastIndex) {
          index = s.indexOf('}}}', lastIndex) + 1;
        } else {
          index = s.indexOf('}}', lastIndex);
        }
        if (index < 0) {
          var text = s.substring(lastIndex - 2);
          var lastDirective = result[result.length - 1];
          if (lastDirective && lastDirective.type == Directive.TEXT)
            lastDirective.value += text;
          else
            result.add(new Directive(Directive.TEXT, text));
          break;
        }

        var value = s.substring(lastIndex, index).trim();
        result.add(new Directive.from(value));
        lastIndex = index + 2;
      }
    }
    return result;
  }
}

class Context {
  dynamic data;
  final Context parent;
  Context(this.data, this.parent);
}


/**
 * Represents the insertion point for nodes into the node tree.
 *
 * Insertion must always occur in reverse order so the insertion points
 * don't conflict.
 */
class NodePath {
  final List<int> path = [];

  NodePath(Node destination) {
    var parent = destination.parentNode;
    while (parent != null) {
      path.insert(0, parent.nodes.indexOf(destination));
      destination = destination.parentNode;
      parent = destination.parentNode;
    }
    if (path.isEmpty) {
      path.add(0);
    }
  }

  Node resolve(Node root) {
    var node = root;
    for (var i in path) {
      node = node.nodes[i];
    }
    return node;
  }

  void insert(Node root, Node item) {
    var insertionNode = root;
    for (var i = 0; i < path.length - 1; ++i) {
      insertionNode = insertionNode.nodes[path[i]];
    }
    insertionNode.nodes.insert(path.last, item);
  }
}

/**
 * Base class for renderers of nodes into a node tree.
 */
abstract class NodeRenderer {
  final NodePath insertionPath;
  NodeRenderer(this.insertionPath);

  void render(Node destination, Context context,
      Map<String, FragmentRenderer> partials);

  resolveBinding(String binding, Context context) {
    if (binding == '.') {
      return context.data;
    }
    var value;
    while (context != null) {
      if (binding.indexOf('.') > 0) {
        value = context.data;

        var path = binding.split('.');
        var i = 0;
        while (value != null && i < path.length) {
          value = value[path[i++]];
        }
      } else if (context.data is Map) {
        value = context.data[binding];
      }
      if (value != null) {
        break;
      }
      context = context.parent;
    }
    if (value is Function) {
      return value();
    }
    return value;
  }
}


/**
 * Renderer which fills in attributes on a node.
 */
class AttributeRenderer extends NodeRenderer {
  final String attributeName;
  final List<Directive> directives;
  final NodeValidator validator;

  AttributeRenderer(NodePath insertionPath, this.attributeName, this.directives,
      this.validator): super(insertionPath) {
  }

  void render(Node destination, data, Map<String, FragmentRenderer> partials) {
    var buffer = new StringBuffer();
    var stack = [data];

    for (var directive in directives) {
      switch(directive.type) {
      case Directive.TEXT:
        buffer.write(directive.value);
        break;
      case Directive.BINDING:
        buffer.write(resolveBinding(directive.value, stack.last));
        break;
      }
    }

    Element element = insertionPath.resolve(destination);
    var value = buffer.toString();
    if (validator.allowsAttribute(element, attributeName, value)) {
      element.attributes[attributeName] = value;
    }
  }
}

/**
 * Base class for renderers which generates nodes from a binding.
 */
abstract class BindingRenderer extends NodeRenderer {
  final String binding;

  BindingRenderer(this.binding, NodePath insertionPath): super(insertionPath) {
  }

  getValue(Context context) {
    return resolveBinding(binding, context);
  }
}


/**
 * Generates text nodes from a binding.
 */
class TextBindingRenderer extends BindingRenderer {
  final Node placeholder;
  TextBindingRenderer(String binding, Node node):
      super(binding, null),
      placeholder = node {
  }

  void render(Node destination, Context context,
      Map<String, FragmentRenderer> partials) {
    var value = getValue(context);
    if (value == null) {
      value = '';
    }
    placeholder.text = '$value';
  }
}

class FragmentRenderer extends BindingRenderer {
  final List<NodeRenderer> renderers = <NodeRenderer>[];
  final List<NodeRenderer> staticRenderers = <NodeRenderer>[];
  final DocumentFragment fragment;

  FragmentRenderer(this.fragment, String binding, NodePath insertionPath):
      super(binding, insertionPath) {
  }

  DocumentFragment expand(Context context,
      Map<String, FragmentRenderer> partials) {
    for (var renderer in staticRenderers) {
      renderer.render(fragment, context, partials);
    }

    var root = fragment.clone(true);
    for (var i = renderers.length - 1; i >= 0; --i) {
      renderers[i].render(root, context, partials);
    }
    return root;
  }

  void addRenderer(NodeRenderer renderer) {
    if (renderer is TextBindingRenderer || renderer is AttributeRenderer) {
      staticRenderers.add(renderer);
    } else {
      renderers.add(renderer);
    }
  }
}

class SectionRenderer extends FragmentRenderer {
  SectionRenderer(String binding, NodePath insertionPath):
      super(new DocumentFragment(), binding, insertionPath) {
  }

  void render(Node destination, Context context,
      Map<String, FragmentRenderer> partials) {
    var value = getValue(context);
    // if (value is Map) {
    //   value = value.values.toList();
    // }

    if (value == null || value == false ||
        (value is num && (value.isNaN || value == 0)) ||
        (value is String && value.length == 0)) {
      return;
    }

    var scopedContext = new Context(value, context);

    if (value is List) {
      var path = insertionPath.path;
      var parent = destination;
      for (var i = 0; i < path.length - 1; ++i) {
        parent = parent.nodes[path[i]];
      }
      var insertionBefore;
      if (parent.nodes.length > path.last) {
        insertionBefore = parent.nodes[path.last];
      }
      for (var item in value) {
        scopedContext.data = item;
        var clone = expand(scopedContext, partials);
        parent.insertBefore(clone, insertionBefore);
      }
      // for (var index = value.length - 1; index >= 0; --index) {
      //   var clone = expand(value[index], partials);
      //   insertionPath.insert(destination, clone);
      // }
    } else {
      insertionPath.insert(destination, expand(scopedContext, partials));
    }
  }
}

class ConditionalRenderer extends FragmentRenderer {
  ConditionalRenderer(String binding, NodePath insertionPath):
      super(new DocumentFragment(), binding, insertionPath) {
  }

  void render(Node destination, Context context,
      Map<String, FragmentRenderer> partials) {
    var value = getValue(context);
    if (value == false || value == null ||
      (value is num && (value.isNaN || value == 0)) ||
      (value is List && value.length == 0) ||
      (value is String && value.length == 0)) {
      var scopedContext = new Context(value, context);
      insertionPath.insert(destination, expand(scopedContext, partials));
    }
  }
}


class UnescapeRenderer extends BindingRenderer {
  UnescapeRenderer(String binding, NodePath insertionPath):
      super(binding, insertionPath) {
  }

  void render(Node destination, Context context,
      Map<String, FragmentRenderer> partials) {
    var value = getValue(context);
    if (value is! String) {
      this.insertionPath.insert(destination, new Text(''));
    }
    var fragment = new DocumentFragment.html(value);
    insertionPath.insert(destination, fragment);
  }
}


class PartialRenderer extends BindingRenderer {

  PartialRenderer(String binding, NodePath insertionPath):
      super(binding, insertionPath) {
  }

  void render(Node destination, Context context,
      Map<String, FragmentRenderer> partials) {
    if (partials == null) {
      throw new StateError('Partial command but no partials provided');
    }
    var partial = partials[binding];
    if (partial == null) {
      throw new StateError('Unable to find partial $binding');
    }
    var fragment = partial.expand(context, partials);
    insertionPath.insert(destination, fragment);
  }
}

class Directive {
  static const int ROOT = 1;
  static const int TEXT = 2;
  static const int BINDING = 3;
  static const int START_SECTION = 4;
  static const int START_INV_SECTION = 5;
  static const int END_SECTION = 6;
  static const int COMMENT_SECTION = 7;
  static const int PARTIAL_SECTION = 8;
  static const int UNESCAPE_SECTION = 9;

  final int type;
  final String value;

  Directive(this.type, this.value) {}

  factory Directive.from(String text) {
    if (text[0] == '#') {
      return new Directive(START_SECTION, text.substring(1).trim());
    } else if (text[0] == '/') {
      return new Directive(END_SECTION, text.substring(1).trim());
    } else if (text[0] == '^') {
      return new Directive(START_INV_SECTION, text.substring(1).trim());
    } else if (text[0] == '!') {
      return new Directive(COMMENT_SECTION, text.substring(1).trim());
    } else if (text[0] == '>') {
      return new Directive(PARTIAL_SECTION, text.substring(1).trim());
    } else if (text[0] == '&') {
      return new Directive(UNESCAPE_SECTION, text.substring(1).trim());
    } else if (text[0] == '{' && text[text.length - 1] == '}') {
      return new Directive(
          Directive.UNESCAPE_SECTION, text.substring(1, text.length - 1));
    }
    return new Directive(BINDING, text);
  }

  NodeRenderer toRenderer(Node node) {
    switch(type) {
    case START_SECTION:
      var path = new NodePath(node);
      node.remove();
      return new SectionRenderer(value, path);
    case BINDING:
      return new TextBindingRenderer(value, node);
    case START_INV_SECTION:
      var path = new NodePath(node);
      node.remove();
      return new ConditionalRenderer(value, path);
    case PARTIAL_SECTION:
      var path = new NodePath(node);
      node.remove();
      return new PartialRenderer(value, path);
    case UNESCAPE_SECTION:
      var path = new NodePath(node);
      node.remove();
      return new UnescapeRenderer(value, path);
    }
    return null;
  }
}
