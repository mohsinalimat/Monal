//
//  XMPPParser.m
//  Monal
//
//  Created by Anurodh Pokharel on 6/30/13.
//
//

#import "XMPPParser.h"


static const int ddLogLevel = LOG_LEVEL_INFO;

@implementation XMPPParser

- (id) initWithData:(NSData *) data
{
    self=[super init];
    [self parseData:data];
    return self;
}

- (id) initWithDictionary:(NSDictionary*) dictionary
{
    self=[super init];
    NSData* stanzaData= [[dictionary objectForKey:@"stanzaString"] dataUsingEncoding:NSUTF8StringEncoding];
    [self parseData:stanzaData];
    return  self;
}

-(void) parseData:(NSData *) data
{
    NSXMLParser* parser = [[NSXMLParser alloc] initWithData:data];
    [parser setShouldProcessNamespaces:NO];
    [parser setShouldReportNamespacePrefixes:NO];
    [parser setShouldResolveExternalEntities:NO];
    [parser setDelegate:self];
    
    [parser parse];
}
 

#pragma mark common parser delegate functions
- (void)parserDidStartDocument:(NSXMLParser *)parser{
	DDLogVerbose(@"parsing start");
  
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict
{
    _messageBuffer=nil;
    _type=[attributeDict objectForKey:@"type"];
    
    if([attributeDict objectForKey:@"from"])
    {
        _from =[attributeDict objectForKey:@"from"];
        NSArray *parts=[_from componentsSeparatedByString:@"/"];
        _user =[parts objectAtIndex:0];
        
        if([parts count]>1) {
            _resource=[parts objectAtIndex:1];
        }
        
        _from = [_from lowercaseString]; // intedned to not break code that expects lowercase
    }
    
    _idval =[attributeDict objectForKey:@"id"] ;
    
    if([attributeDict objectForKey:@"to"])
    {
        _to =[[(NSString*)[attributeDict objectForKey:@"to"] componentsSeparatedByString:@"/" ] objectAtIndex:0];
        _to=[_to lowercaseString];
    }
    
    //remove any  resource markers and get user
    _user=[[_user lowercaseString] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    if(!_messageBuffer)
    {
           _messageBuffer=[[NSMutableString alloc] init];
    }
    
    [_messageBuffer appendString:string];
}


- (void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)whitespaceString
{
	DDLogVerbose(@"found ignorable whitespace: %@", whitespaceString);
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	DDLogVerbose(@"Error: line: %d , col: %d desc: %@ ",[parser lineNumber],
                [parser columnNumber], [parseError localizedDescription]);
	
    
}

@end
