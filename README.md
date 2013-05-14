Dart Experimental DOM templating with sanitization.
===================

This library is an experimental implementation of a Dart DOM templating
library based on Mustache templating syntax which leverages DOM sanitization
libraries to perform fully validated sanitization.

Note that this is quite experimental and does not support full Mustache
templating syntax.

Documentation
-------------

## Example
```dart
  import 'package:dom_mustache/mustache.dart';

  main() {
    var template = new Template.fromHtml('''
        <ul>
          {{#users}}
            <li class='{{status}}'>{{lastName}} {{firstName}}</li>
          {{/users}}
        </ul>''');

    var dom = template.render({
        'users': [
          { 'firstName': 'Pete' },
          { 'lastName': 'Blois'},
        ]});

    document.body.append(dom);
  }
```

The templating allows operation with
[Safe-DOM](https://github.com/blois/safe-dom) NodeValidators to allow control
over what contents are allowed and where. The sanitization can be customized 
by explicitly providing a node validator:

```dart
  import 'package:safe_dom/validators.dart';
  import 'package:dom_mustache/mustache.dart';

  main() {
    // Only allow src images to point to URLs on our domain.
    var template = new Template.fromHtml('<img src="{{profileUrl}}"/>',
        new NodeValidator(new SameOriginUriPolicy()));
    ...
  }
```

The library also allows using pre-constructed document fragments as template
input so the templating validation can be split from the template validation:

```dart
  import 'package:safe_dom/parser.dart' as safe_dom;
  import 'package:dom_mustache/mustache.dart';

  main() {
    // create a fragment allowing URIs anywhere
    var templateFragment = safe_dom.createFragment(document.body,
        '''<div>
            <img src="http://example.com/banner.jpg/>
            <img src="{{profileUrl}}"/>
           </div>''',
        new NodeValidator(new SameProtocolUriPolicy()));

    // Only allow template-expanded URIs on our domain.
    var template = new Template.fromFragment('<img src="{{profileUrl}}"/>',
        new NodeValidator(new SameOriginUriPolicy()));
    ...
  }
```


Running Tests
-------------

First, use the [Pub Package Manager][pub] to install dependencies:
```bash
    pub install
```

To run browser tests on [Dartium], simply open **test/dom_mustache_test.html**
in Dartium.
