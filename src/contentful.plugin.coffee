# Export Plugin
module.exports = (BasePlugin) ->
	# Requires
	_				= require 'lodash'
	W				= require 'when'
	S				= require 'string'
	path			= require 'path'
	contentful		= require 'contentful'
	pluralize		= require 'pluralize'
	querystring		= require 'querystring'
	
	# errors
	errors =
		no_token: 'Missing required options for roots-contentful. Please ensure
		`access_token` and `space_id` are present.'
		no_type_id: 'One or more of your content types is missing an `id` value'
		sys_conflict: 'One of your content types has `sys` as a field. This is
		reserved for storing Contentful system metadata, please rename this field to
		a different value.'
  
	config = null
	client = null
	
	# Define Plugin
	class ContentfulPlugin extends BasePlugin
		# Plugin name
		name: 'contentful'

		# Render Before
		# Read the contentful entries here
		renderBefore: (opts) ->
			{templateData} = opts
            
			# Prepare
			docpad = @docpad
			config = @getConfig()

			# Extend the template data
			templateData.contentful or= {}
			templateData.contentful.contentTypes or= {}

			# Load contentful
			unless contentful?
				client = contentful.createClient
					accessToken:	config.accessToken
					space:			config.spaceId
					
				configure_content(config.contentTypes).with(@)
				    .then(get_all_content)
				    .tap(set_urls)
				    .tap(set_locals)

			# Chain
			@
			
		###*
		 * Configures content types set in app.coffee. Sets default values if
		 * optional config options are missing.
		 * @param {Array} types - content_types set in app.coffee extension config
		 * @return {Promise} - returns an array of configured content types
		###

		configure_content = (types) ->
			if _.isPlainObject(types) then types = reconfigure_alt_type_config(types)
			W.map types, (t) ->
				if not t.id then return W.reject(errors.no_type_id)
				t.filters ?= {}
				if (not t.name || (t.template && not t.path))
					return W client.contentType(t.id).then (res) ->
						t.name ?= pluralize(S(res.name).toLowerCase().underscore().s)
						if t.template
							t.path ?= (e) -> "#{t.name}/#{S(e[res.displayField]).slugify().s}"
						return t
				return W.resolve(t)

		###*
		 * Reconfigures content types set in app.coffee using an object instead of
		 * an array. The keys of the object set as the `name` option in the config
		 * @param {Object} types - content_types set in app.coffee extension config
		 * @return {Promise} - returns an array of content types
		###

		reconfigure_alt_type_config = (types) ->
			_.reduce types, (res, type, k) ->
				type.name = k
				res.push(type)
				res
			, []

		###*
		 * Fetches data from Contentful for content types, and formats the raw data
		 * @param {Array} types - configured content_type objects
		 * @return {Promise} - returns formatted locals object with all content
		###

		get_all_content = (types) ->
			W.map types, (t) =>
				fetch_content(t)
					.then(format_content)
					.then((c) -> t.content = c)
					.yield(t)

		###*
		 * Fetch entries for a single content type object
		 * @param {Object} type - content type object
		 * @return {Promise} - returns response from Contentful API
		###

		fetch_content = (type) ->
			W client.entries(_.merge(type.filters, content_type: type.id))

		###*
		 * Formats raw response from Contentful
		 * @param {Object} content - entries API response for a content type
		 * @return {Promise} - returns formatted content type entries object
		###

		format_content = (content) -> W.map(content, format_entry)

		###*
		 * Formats a single entry object from Contentful API response
		 * @param {Object} e - single entry object from API response
		 * @return {Promise} - returns formatted entry object
		###

		format_entry = (e) ->
			if _.has(e.fields, 'sys') then return W.reject(errors.sys_conflict)
			_.assign(_.omit(e, 'fields'), e.fields)

		###*
		 * Sets `_url` property on content with single entry views
		 * @param {Array} types - content type objects
		 * return {Promise} - promise when urls are set
		###

		set_urls = (types) ->
			W.map types, (t) ->
				if t.template then W.map t.content, (entry) ->
					entry._url = "/#{t.path(entry)}.html"

		###*
		 * Builds locals object from types objects with content
		 * @param {Array} types - populated content type objects
		 * @return {Promise} - promise for when complete
		###

		set_locals = (types) ->
			W.map types, (t) => @roots.config.locals.contentful[t.name] = t.content

		###*
		 * Compiles single entry views for content types
		 * @param {Array} types - Populated content type objects
		 * @return {Promise} - promise for when compilation is finished
		###

		compile_entries = (types) ->
			W.map types, (t) =>
				if not t.template then return W.resolve()
				W.map t.content, (entry) =>
					template = path.join(@roots.root, t.template)
					@roots.config.locals.entry = entry
					compiler = _.find @roots.config.compilers, (c) ->
						_.contains(c.extensions, path.extname(template).substring(1))
					compiler.renderFile(template, @roots.config.locals)
						.then((res) => @util.write("#{t.path(entry)}.html", res.result))

		###*
		 * View helper for accessing the actual url from a Contentful asset
		 * and appends any query string params
		 * @param {Object} asset - Asset object returned from Contentful API
		 * @param {Object} opts - Query string params to append to the URL
		 * @return {String} - URL string for the asset
		###

		asset_view_helper = (asset = {}, params) ->
			asset.fields ?= {}
			asset.fields.file ?= {}
			url = asset.fields.file.url
			if params then "#{url}?#{querystring.stringify(params)}" else url
		

		