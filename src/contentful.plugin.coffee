# Export Plugin
module.exports = (BasePlugin) ->
	# Requires
	_				= require 'lodash'
	W				= require 'when'
	S				= require 'string'
	path				= require 'path'
	contentful			= require 'contentful'
	pluralize			= require 'pluralize'
	querystring			= require 'querystring'
	{TaskGroup}			= require 'taskgroup'

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
	td = null

	# Define Plugin
	class ContentfulPlugin extends BasePlugin
		# Plugin name
		name: 'contentful'

		config:
			collectionDefaults:
				connectionString: null
				relativeDirPath: null # defaults to collectionName
				extension: ".json"
				injectDocumentHelper: null
				collectionName: "contentful"
				contentTypeId: null
				sort: null # http://documentcloud.github.io/backbone/#Collection-comparator
				meta: {}
				filters: []
			collections: []

		# DocPad v6.24.0+ Compatible
		# Configuration
		setConfig: ->
			# Prepare
			super
			config = @getConfig()
			# Adjust
			config.collections = config.collections.map (collection) ->
				return _.defaults(collection, config.collectionDefaults)
			# Chain
			@

		getBasePath: (collectionConfig) ->
			"#{collectionConfig.relativeDirPath or collectionConfig.collectionName}/"

		# Fetch our documents from contentful
		# next(err, contentfulDocs)
		fetchContentfulCollection: (collectionConfig, next) ->
			client = contentful.createClient
				accessToken: collectionConfig.accessToken
				space: collectionConfig.spaceId
				
			client.entries(collectionConfig.filters, (err, contentfulDocs) ->
				next err, contentfulDocs
			)
			# Chain
			@

		# convert JSON doc from contentful to DocPad-style document/file model
		# "body" of docpad doc is a JSON string of the contentful doc, meta includes all data in contentful doc
		contentfulDocToDocpadDoc: (collectionConfig, contentfulDoc, next) ->
			# Prepare
			docpad = @docpad
			id = contentfulDoc.sys.id.toString();

			documentAttributes =
				data: JSON.stringify(contentfulDoc, null, '\t')
				meta: _.defaults(
					{},
					collectionConfig.meta,

					contenfulId: id
					contentfulCollection: collectionConfig.collectionName
					# todo check for ctime/mtime/date/etc. fields and upgrade them to Date objects (?)
					relativePath: "#{@getBasePath(collectionConfig)}#{id}#{collectionConfig.extension}"
					original: contentfulDoc, # this gives the original document without DocPad overwriting certain fields

					contentfulDoc # this puts all of the document attributes into the metadata, but some will be overwritten
				)

			# Fetch docpad doc (if it already exists in docpad db, otherwise null)
			document = docpad.getFile({contentfulId:id})

			# Existing document
			if document?
				# todo: check mtime (if available) and return now for docs that haven't changed
				document.set(documentAttributes)

			# New Document
			else
				# Create document from opts
				document = docpad.createDocument(documentAttributes)

			# Inject document helper
			collectionConfig.injectDocumentHelper?.call(@, document)

			# Load the document
			document.action 'load', (err) ->
				# Check
				return next(err, document)  if err

				# Add it to the database (with b/c compat)
				docpad.addModel?(document) or docpad.getDatabase().add(document)

				# Complete
				next(null, document)

			# Return the document
			return document

		addContentfulCollectionToDb: (collectionConfig, next) ->
			docpad = @docpad
			plugin = @
			plugin.fetchContentfulCollection collectionConfig, (err, contentfulDocs) ->
				return next(err) if err

				docpad.log('debug', "Retrieved #{contentfulDocs.length} entry in collection #{collectionConfig.collectionName}, converting to DocPad docs...")

				docTasks  = new TaskGroup({concurrency:0}).done (err) ->
					return next(err) if err
					docpad.log('debug', "Converted #{contentfulDocs.length} entry documents into DocPad docs...")
					next()

				contentfulDocs.forEach (contentfulDoc) ->
					docTasks.addTask (complete) ->
						docpad.log('debug', "Inserting #{contentfulDoc.sys.id} into DocPad database...")
						plugin.contentfulDocToDocpadDoc collectionConfig, contentfulDoc, (err) ->
							return complete(err) if err
							docpad.log('debug', 'inserted')
							complete()

				docTasks.run()

		# =============================
		# Events

		# Populate Collections
		# Import MongoDB Data into the Database
		populateCollections: (opts, next) ->
			# Prepare
			plugin = @
			docpad = @docpad
			config = @getConfig()

			# Log
			docpad.log('info', "Importing Contentful collection(s)...")

			# concurrency:0 means run all tasks simultaneously
			collectionTasks = new TaskGroup({concurrency:0}).done (err) ->
				return next(err) if err

				# Log
				docpad.log('info', "Imported all contentful docs...")

				# Complete
				return next()

			config.collections.forEach (collectionConfig) ->
				collectionTasks.addTask (complete) ->
					plugin.addContentfulCollectionToDb collectionConfig, (err) ->
						complete(err) if err

						docs = docpad.getFiles {contentfulCollection: collectionConfig.collectionName}, collectionConfig.sort

						# Set the collection
						docpad.setCollection(collectionConfig.collectionName, docs)

						docpad.log('info', "Created DocPad collection \"#{collectionConfig.collectionName}\" with #{docs.length} documents from Contenful")
						complete()
						
			collectionTasks.run()

			# Chain
			@
      






#		# Render Before
#		# Read the contentful entries here
#		renderBefore: (opts) ->
#			{templateData} = opts
#            
#			# Prepare
#			docpad = @docpad
#			config = @getConfig()
#
#			# Extend the template data
#			templateData.contentful or= {}
#			td = templateData
#
#			console.info("contentful: processing")
#
#			# Load contentful
#			client = contentful.createClient
#				accessToken:	config.accessToken
#				space:		config.spaceId
#
#			console.info("contentful: client initialized")
#					
#			configure_content(config.contentTypes).with(@)
#				.then(get_all_content)
#				.tap(set_urls)
#				.tap(set_results)
#
#			console.info("contentful: content imported")
#
#			console.info("contentful: content processed")
#
#			# Chain
#			@
			
		###*
		 * Configures content types set in app.coffee. Sets default values if
		 * optional config options are missing.
		 * @param {Array} types - content_types set in app.coffee extension config
		 * @return {Promise} - returns an array of configured content types
		###

#		configure_content = (types) ->
#			if _.isPlainObject(types) then types = reconfigure_alt_type_config(types)
#			W.map types, (t) ->
#				if not t.id then return W.reject(errors.no_type_id)
#				t.filters ?= {}
#				if (not t.name || (t.template && not t.path))
#					return W client.contentType(t.id).then (res) ->
#						t.name ?= pluralize(S(res.name).toLowerCase().underscore().s)
#						if t.template
#							t.path ?= (e) -> "#{t.name}/#{S(e[res.displayField]).slugify().s}"
#						return t
#				return W.resolve(t)

		###*
		 * Reconfigures content types set in app.coffee using an object instead of
		 * an array. The keys of the object set as the `name` option in the config
		 * @param {Object} types - content_types set in app.coffee extension config
		 * @return {Promise} - returns an array of content types
		###

#		reconfigure_alt_type_config = (types) ->
#			_.reduce types, (res, type, k) ->
#				type.name = k
#				res.push(type)
#				res
#			, []

		###*
		 * Fetches data from Contentful for content types, and formats the raw data
		 * @param {Array} types - configured content_type objects
		 * @return {Promise} - returns formatted locals object with all content
		###

#		get_all_content = (types) ->
#			W.map types, (t) =>
#				fetch_content(t)
#					.then(format_content)
#					.then((c) -> t.content = c)
#					.yield(t)

		###*
		 * Fetch entries for a single content type object
		 * @param {Object} type - content type object
		 * @return {Promise} - returns response from Contentful API
		###

#		fetch_content = (type) ->
#			W client.entries(_.merge(type.filters, content_type: type.id))

		###*
		 * Formats raw response from Contentful
		 * @param {Object} content - entries API response for a content type
		 * @return {Promise} - returns formatted content type entries object
		###

#		format_content = (content) -> W.map(content, format_entry)

		###*
		 * Formats a single entry object from Contentful API response
		 * @param {Object} e - single entry object from API response
		 * @return {Promise} - returns formatted entry object
		###

#		format_entry = (e) ->
#			if _.has(e.fields, 'sys') then return W.reject(errors.sys_conflict)
#			_.assign(_.omit(e, 'fields'), e.fields)

		###*
		 * Sets `_url` property on content with single entry views
		 * @param {Array} types - content type objects
		 * return {Promise} - promise when urls are set
		###

#		set_urls = (types) ->
#			W.map types, (t) ->
#				if t.template then W.map t.content, (entry) ->
#					entry._url = "/#{t.path(entry)}.html"

		###*
		 * Builds locals object from types objects with content
		 * @param {Array} types - populated content type objects
		 * @return {Promise} - promise for when complete
		###

#		set_locals = (types) ->
#			W.map types, (t) => @roots.config.locals.contentful[t.name] = t.content
#
#		set_results = (types) ->
#			W.map types, (t) => 
#				console.info("contentful type: " + JSON.stringify(t))
#				td.contentful[t.name] = t.content

		###*
		 * Compiles single entry views for content types
		 * @param {Array} types - Populated content type objects
		 * @return {Promise} - promise for when compilation is finished
		###

#		compile_entries = (types) ->
#			W.map types, (t) =>
#				if not t.template then return W.resolve()
#				W.map t.content, (entry) =>
#					template = path.join(@roots.root, t.template)
#					@roots.config.locals.entry = entry
#					compiler = _.find @roots.config.compilers, (c) ->
#						_.contains(c.extensions, path.extname(template).substring(1))
#					compiler.renderFile(template, @roots.config.locals)
#						.then((res) => @util.write("#{t.path(entry)}.html", res.result))

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
		

		