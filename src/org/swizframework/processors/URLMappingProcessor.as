package org.swizframework.processors
{
	import flash.events.Event;
	
	import mx.events.BrowserChangeEvent;
	import mx.managers.BrowserManager;
	import mx.managers.IBrowserManager;
	
	import org.swizframework.core.Bean;
	import org.swizframework.core.ISwiz;
	import org.swizframework.metadata.EventHandlerMetadataTag;
	import org.swizframework.metadata.URLMapping;
	import org.swizframework.reflection.ClassConstant;
	import org.swizframework.reflection.Constant;
	import org.swizframework.reflection.IMetadataTag;
	import org.swizframework.reflection.TypeCache;
	import org.swizframework.reflection.TypeDescriptor;
	
	/**
	 * [URLMapping] metadata processor
	 */
	public class URLMappingProcessor extends BaseMetadataProcessor
	{
		
		// ========================================
		// protected properties
		// ========================================
		
		/**
		 * Reference to the Flex SDK BrowserManager singleton
		 */
		protected var browserManager:IBrowserManager;
		
		/**
		 * List of mediate event types
		 */
		protected var mediateEventTypes:Array = [];
		
		/**
		 * List of attached urll mappings
		 */
		protected var urlMappings:Array = [];
		
		/**
		 * List of url regexs to match browser urls against
		 */
		protected var regexs:Array = [];
		
		/**
		 * List of methods to call
		 */
		protected var methods:Array = [];
		
		// ========================================
		// public properties
		// ========================================
		
		public var defaultURL:String;
		
		public var defaultTitle:String;
		
		// ========================================
		// constructor
		// ========================================
		
		/**
		 * Constructor
		 */
		public function URLMappingProcessor()
		{
			super( [ "URLMapping" ], URLMapping );
		}
		
		// ========================================
		// public methods
		// ========================================
		
		/**
		 * Init
		 */
		override public function init( swiz:ISwiz ):void
		{
			// initialize the browser manager
			browserManager = BrowserManager.getInstance();
			browserManager.addEventListener( BrowserChangeEvent.BROWSER_URL_CHANGE, browserUrlChangeHandler );
			browserManager.init( defaultURL, defaultTitle );
			
			super.init( swiz );
		}
		
		/**
		 * Executed when a new [URLMapping] is found
		 */
		override public function setUpMetadataTag( metadataTag:IMetadataTag, bean:Bean ):void
		{
			var urlMapping:URLMapping = URLMapping( metadataTag );
			var method:Function = bean.source[ metadataTag.host.name ] as Function;
			
			addURLMapping( urlMapping, method );
		}
		
		/**
		 * Executed when a [URLMapping] has been removed
		 */
		override public function tearDownMetadataTag(metadataTag:IMetadataTag, bean:Bean):void
		{
			var urlMapping:URLMapping = URLMapping( metadataTag );
			var method:Function = bean.source[ metadataTag.host.name ] as Function;
			
			removeURLMapping( urlMapping, method );
		}
		
		// ========================================
		// protected methods
		// ========================================
		
		/**
		 * Add a URL mapping
		 */
		protected function addURLMapping( urlMapping:URLMapping, method:Function ):void
		{
			var index:int = urlMappings.length;
			var regex:RegExp = new RegExp( "^" + urlMapping.url.replace( /[\\\+\?\|\[\]\(\)\^\$\.\,\#]{1}/g, "\$1" ).replace( /\*/g, ".*" ).replace( /\{.+?\}/g, "(.+?)" ) + "$" );
			
			// add mapping to arrays
			urlMappings[ index ] = urlMapping;
			methods[ index ] = method;
			regexs[ index ] = regex;
			
			// check if mapping matches the current url
			var url:String = browserManager.url != null ? browserManager.url.substr( browserManager.url.indexOf( "#" ) + 1 ) : "";
			var match:Array = url.match( regex );
			
			// if a match is found, process the url change
			if ( match != null )
			{
				processURLMapping( match, urlMapping, method );
			}
			
			addMediate( urlMapping );
		}
		
		/**
		 * Remove a URL mapping
		 */
		protected function removeURLMapping( urlMapping:URLMapping, method:Function ):void
		{
			var index:int = urlMappings.indexOf( urlMapping );
			
			if ( index != -1 )
			{
				// remove mapping from arrays
				urlMappings.splice( index, 1 );
				methods.splice( index, 1 );
				regexs.splice( index, 1 );
			}
			
			removeMediate( urlMapping );
		}
		
		/**
		 * Add a reverse URL mapping if possible
		 */
		protected function addMediate( urlMapping:URLMapping ):void
		{
			if ( urlMapping.host.hasMetadataTagByName( "Mediate" ) || urlMapping.host.hasMetadataTagByName( "EventHandler" ) )
			{
				var mediateTag:EventHandlerMetadataTag = new EventHandlerMetadataTag();
				
				mediateTag.copyFrom( urlMapping.host.getMetadataTagByName( urlMapping.host.hasMetadataTagByName( "Mediate" ) ? "Mediate" : "EventHandler" ) );
				
				if( mediateTag.event.substr( -2 ) == ".*" )
				{
					var clazz:Class = ClassConstant.getClass( swiz.domain, mediateTag.event, swiz.config.eventPackages );
					var td:TypeDescriptor = TypeCache.getTypeDescriptor( clazz, swiz.domain );
					
					for each( var constant:Constant in td.constants )
					{
						addEventHandler( urlMapping, constant.value );
					}
				}
				else
				{
					var eventType:String = parseEventTypeExpression( mediateTag.event );
					
					addEventHandler( urlMapping, eventType );
				}
			}
		}
		
		/**
		 * Remove a reverse URL mapping
		 */
		protected function removeMediate( urlMapping:URLMapping ):void
		{
			if ( urlMapping.host.hasMetadataTagByName( "Mediate" ) || urlMapping.host.hasMetadataTagByName( "EventHandler" ) )
			{
				var mediateTag:EventHandlerMetadataTag = new EventHandlerMetadataTag();
				
				mediateTag.copyFrom( urlMapping.host.getMetadataTagByName( urlMapping.host.hasMetadataTagByName( "Mediate" ) ? "Mediate" : "EventHandler" ) );
				
				if( mediateTag.event.substr( -2 ) == ".*" )
				{
					var clazz:Class = ClassConstant.getClass( swiz.domain, mediateTag.event, swiz.config.eventPackages );
					var td:TypeDescriptor = TypeCache.getTypeDescriptor( clazz, swiz.domain );
					
					for each( var constant:Constant in td.constants )
					{
						removeEventHandler( urlMapping, constant.value );
					}
				}
				else
				{
					var eventType:String = parseEventTypeExpression( mediateTag.event );
					
					removeEventHandler( urlMapping, eventType );
				}
			}
		}
		
		/**
		 * Add mediate event handler
		 */
		protected function addEventHandler( urlMapping:URLMapping, eventType:String ):void
		{
			swiz.dispatcher.addEventListener( eventType, mediateEventHandler );
			mediateEventTypes[ mediateEventTypes.length ] = eventType;
		}
		
		/**
		 * Remove mediate event handler
		 */
		protected function removeEventHandler( urlMapping:URLMapping, eventType:String ):void
		{
			swiz.dispatcher.removeEventListener( eventType, mediateEventHandler );
			mediateEventTypes.splice( mediateEventTypes.lastIndexOf( eventType ), 1 );
		}
		
		/**
		 * Process an incoming URL change
		 */
		protected function processURLMapping( match:Array, urlMapping:URLMapping, method:Function ):void
		{
			var parameters:Array = [];
			var placeholders:Array = urlMapping.url.match( /\{\d+\}/g );
			
			for each ( var placeholder:String in placeholders )
			{
				var index:int = int( placeholder.substr( 1, placeholder.length - 2 ) ) + 1;
				
				parameters[ parameters.length ] = unescape( match[ index ] );
			}
			
			method.apply( null, parameters );
			
			if( urlMapping.title != null )
			{
				browserManager.setTitle( constructUrl( urlMapping.title, parameters ) );
			}
		}
		
		/**
		 * Executed when the browser URL changes
		 */
		protected function browserUrlChangeHandler( event:BrowserChangeEvent ):void
		{
			var url:String = event.url != null && event.url.indexOf( "#" ) > -1 ? event.url.substr( event.url.indexOf( "#" ) + 1 ) : "";
			
			for ( var i:int = 0; i < regexs.length; i++ )
			{
				var match:Array = url.match( regexs[ i ] );
				
				if ( match != null )
				{
					processURLMapping( match, urlMappings[ i ] as URLMapping, methods[ i ] as Function );
				}
			}
		}
		
		/**
		 * Sets the url when ever a mediated method is called
		 */
		protected function mediateEventHandler( event:Event ):void
		{
			var urlMapping:URLMapping = URLMapping( urlMappings[ mediateEventTypes.lastIndexOf( event.type ) ] );
			var mediate:IMetadataTag = urlMapping.host.getMetadataTagByName( "Mediate" );
			var args:Array = mediate.hasArg( "properties" ) ? getEventArgs( event, mediate.getArg( "properties" ).value.split( /\s*,\s*/ ) ) : null;
			
			if( urlMapping != null )
			{
				var url:String = urlMapping.url;
				
				url = url.replace( /\*/g, "" );
				
				if( args != null )
				{
					for ( var i:int = 0; i < args.length; i++ )
					{
						url = url.replace( new RegExp( "\\{" + i + "\\}", "g" ), escape( args[ i ] ) );
					}
				}
				
				browserManager.setFragment( url );
				
				if( urlMapping.title != null )
				{
					browserManager.setTitle( constructUrl( urlMapping.title, args ) );
				}
			}
		}
		
		/**
		 * 
		 */
		protected function constructUrl( url:String, params:Array ):String
		{
			for( var i:int = 0; i < params.length; i++ )
			{
				url = url.replace( new RegExp( "\\{" + i + "\\}", "g" ), params[ i ] );
			}
			
			return url;
		}
		
		/**
		 * 
		 */
		protected function getEventArgs( event:Event, properties:Array ):Array
		{
			var args:Array = [];
			
			for each( var property:String in properties )
			{
				args[ args.length ] = event[ property ];
			}
			
			return args;
		}
		
		/**
		 * 
		 */
		protected function parseEventTypeExpression( value:String ):String
		{
			if( swiz.config.strict && ClassConstant.isClassConstant( value ) )
			{
				return ClassConstant.getConstantValue( swiz.domain, ClassConstant.getClass( swiz.domain, value, swiz.config.eventPackages ), ClassConstant.getConstantName( value ) );
			}
			else
			{
				return value;
			}
		}
		
	}
}