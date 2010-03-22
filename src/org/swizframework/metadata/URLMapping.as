package org.swizframework.metadata
{
	import org.swizframework.reflection.BaseMetadataTag;
	import org.swizframework.reflection.IMetadataTag;
	
	public class URLMapping extends BaseMetadataTag
	{
		
		// ========================================
		// protected properties
		// ========================================
		
		protected var _url:String;
		
		protected var _title:String;
		
		// ========================================
		// public properties
		// ========================================
		
		public function get url():String
		{
			return _url;
		}
		
		public function get title():String
		{
			return _title;
		}
		
		// ========================================
		// constructor
		// ========================================
		
		public function URLMapping()
		{
			super();
			
			defaultArgName = "url";
		}
		
		// ========================================
		// public methods
		// ========================================
		
		override public function copyFrom( metadataTag:IMetadataTag ):void
		{
			super.copyFrom( metadataTag );
			
			if( hasArg( "url" ) )
			{
				_url = getArg( "url" ).value;
			}
			
			if( hasArg( "title" ) )
			{
				_title = getArg( "title" ).value;
			}
		}
		
	}
}