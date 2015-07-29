# Contentful Plugin for [DocPad](http://docpad.org)

<!-- BADGES/ -->

[![Build Status](https://img.shields.io/travis/markphillips100/docpad-plugin-contentful/master.svg)](http://travis-ci.org/markphillips100/docpad-plugin-contentful "Check this project's build status on TravisCI")
[![NPM version](https://img.shields.io/npm/v/docpad-plugin-contentful.svg)](https://npmjs.org/package/docpad-plugin-contentful "View this project on NPM")
[![NPM downloads](https://img.shields.io/npm/dm/docpad-plugin-contentful.svg)](https://npmjs.org/package/docpad-plugin-contentful "View this project on NPM")
[![Dependency Status](https://img.shields.io/david/markphillips100/docpad-plugin-contentful.svg)](https://david-dm.org/markphillips100/docpad-plugin-contentful)
[![Dev Dependency Status](https://img.shields.io/david/dev/markphillips100/docpad-plugin-contentful.svg)](https://david-dm.org/markphillips100/docpad-plugin-contentful#info=devDependencies)<br/>


<!-- /BADGES -->


Import Contentful entries into DocPad collections.

Inspired by and based on https://github.com/nfriedly/docpad-plugin-mongodb

<!-- INSTALL/ -->

## Install

``` bash
docpad install contentful
```

<!-- /INSTALL -->


## Configuration

### Simple example

Add the following to your [docpad configuration file](http://docpad.org/docs/config):

``` coffee
plugins:
  contentful:
    collections: [
      accessToken: "23e9e3d2eb2a2303d64262692..."
	  spaceId: "sd0nae..."
      collectionName: "posts"
      relativeDirPath: "blog"
      extension: ".html"
      sort: date: 1 # newest first
      meta:
        layout: "blogpost"
    ]
```

### Fancy example

``` coffee
plugins:
  contentful:
    collectionDefaults:
		accessToken: "23e9e3d2eb2a2303d64262692..."
		spaceId: "sd0nae..."
	  
    collections: [
      {
        # accessToken and spaceId are imported from the defaults
        collectionName: "posts"
        relativeDirPath: "blog"
        extension: '.html.eco'
        sort: date: 1 # newest first
        injectDocumentHelper: (document) ->
          document.setMeta(
            layout: 'default'
            tags: (document.get('tags') or []).concat(['post'])
            data: """
              <%- @partial('post/'+@document.tumblr.type, @extend({}, @document, @document.tumblr)) %>
              """
          )
      },

      {
        collectionName: "comments"
        filters: content_type: "a content type id"
        extension: '.html.markup'
        sort: date: -1 #oldest first
        meta:
          write: false
      },

      {
        spaceId: "some other space id"
        filters: content_type: "another content type id"
        collectionName: "stats"
        extension: ".json"
      }
    ]
```

### Config details:

Each configuration object in `collections` inherits default values from `collectionDefaults` and then from the built-in defaults:

```coffee
	accessToken: "accessToken" # the api key for the accessing the Contentful space
	spaceId: "spaceId" # the spaceId for the space in Contentful
    relativeDirPath: null # defaults to collectionName
    extension: ".json"
    injectDocumentHelper: null # function to format documents
    collectionName: "my-content" # name to give the collection, defaults to "contentful"
    sort: null # http://documentcloud.github.io/backbone/#Collection-comparator
    meta: {} # automatically added to each document
    filters: {} # optional Contentful query properties.  "content_type" is usually the minimum required.
```

The default directory for where the imported documents will go inside is the collectionName.
You can override this using the `relativeDirPath` plugin config option.

The default content for the imported documents is JSON data. You can can customise this with the `injectDocumentHelper`
plugin configuration option which is a function that takes in a single [Document Model](https://github.com/bevry/docpad/blob/master/src/lib/models/document.coffee).

If you would like to render a template, add a layout, and change the extension, you can do it via the `meta` configuration
option or you can get fancy and do this with (for example) the
[eco](https://github.com/docpad/docpad-plugin-eco) and [partials](https://github.com/docpad/docpad-plugin-partials)
plugins and following collection configuration:

``` coffee
extension: '.html.eco'
injectDocumentHelper: (document) ->
  document.setMeta(
    layout: 'default'
    tags: (document.get('tags') or []).concat(['post'])
    data: """
			<%- @partial('post/'+@document.tumblr.type, @extend({}, @document, @document.tumblr)) %>
			"""
  )
```

The `sort` field is [passed as the comparator to Query Engine](https://learn.bevry.me/queryengine/guide#querying) which tries it as a
[MongoDB-style sort](http://docs.mongodb.org/manual/reference/method/cursor.sort/) first and then a
[Backbone.js comparator](http://documentcloud.github.io/backbone/#Collection-comparator) second.

### Creating a File Listing

As imported documents are just like normal documents, you can also list them just as you would other documents. Here is an example of a `index.html.eco` file that would output the titles and links to all the blog posts from the simple example above:

``` erb
<h2>Blog:</h2>
<ul><% for post in @getCollection('posts').toJSON(): %>
	<li>
		<a href="<%= post.url %>"><%= post.title %></a>
	</li>
<% end %></ul>
```


<!-- LICENSE/ -->

## License

Unless stated otherwise all works are:

- Copyright &copy; Mark Phillips

and licensed under:

- The incredibly [permissive](http://en.wikipedia.org/wiki/Permissive_free_software_licence) [MIT License](http://opensource.org/licenses/mit-license.php)

<!-- /LICENSE -->


