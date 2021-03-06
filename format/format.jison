%{
	var node = {};
	
	node.Root = function Root(s){
		this.value = s;
	};
	node.Comment = function Comment(s){
		this.value = s.slice(2);
	};
	node.Tag = function Tag(s, v){
		this.name = s;
		this.value = +v;
	};
	node.TagOffset = function TagOffset(s, f, o){
		this.name = s;
		this.base = f;
		this.offset = +o;
	};
	node.Node = function Node(s, v){
		this.name = s;
		this.schema = v;
	};
	node.Record = function Record(s, v){
		this.name = s;
		this.schema = v;
	};
	node.Type = function Type(){
		this.name = null;
		this.type = null;
	};
	node.NodeType = function NodeType(t, s, o){
		this.name = s;
		this.type = t;
		this.options = {};
		o.forEach(function(a){
			this.options[a[0]] = a[1];
		}, this);
	};
	node.SimpleType = function SimpleType(t, s){
		this.name = s;
		this.type = t;
	};
	node.Group = function Group(s, a){
		this.name = s;
		this.values = a;
	};
	node.Array = function Array(t, l, s){
		this.name = s;
		this.length = l;
		this.type = t;
	};
	node.ByteStream = function ByteStream(l, s){
		this.name = s;
		this.length = l;
		this.type = 'ByteStream';
	};
	node.Script = function Script(s){
		this.script = s;
	};

	var simpleTypeCode = function(base, simple, offset){
		var code = "";
		switch(simple.type){
			case "Byte":
				code = base+"."+simple.name+" = this.data.readUInt8("+offset.value+");";
				code += offset.add(1);
				return code;
			case "Word":
				code = base+"."+simple.name+" = this.data.readUInt16("+offset.value+");";
				code += offset.add(2);
				return code;
			case "UInt8": case "Int8":
				code = base+"."+simple.name+" = this.data.read"+simple.type+"("+offset.value+");";
				code += offset.add(1);
				return code;
			case "UInt16": case "Int16":
				code = base+"."+simple.name+" = this.data.read"+simple.type+"LE("+offset.value+");";
				code += offset.add(2);
				return code;
			case "UInt32": case "Int32":
				code = base+"."+simple.name+" = this.data.read"+simple.type+"LE("+offset.value+");";
				code += offset.add(4);
				return code;
			case "WString":
				code = "tmp = this.data.readUInt16LE("+offset.value+");";
				code += offset.add(2) + offset.toObj();
				code += " for("+base+"."+simple.name+"='';tmp-->0;){"+base+"."+simple.name+"+=String.fromCharCode(this.data.readUInt16LE("+offset.value+"));"+offset.add(2)+"}";
				return code;
			case "ColorRef":
				code = base+"."+simple.name+" = this.data.readUInt32LE("+offset.value+");";
				code += offset.add(4);
				return code;
			default: return "// FIXME: unprocessed simple type: "+simple.type;
		}
	};

	var generateCode = function(format){
		var RT = "root", wc = "", tags = {}, tagInverse = [];
		format.forEach(function(o){
			if(o == null) return;
			if(o instanceof node.Root){
				rootObj = o.value;
			}
		});
		wc = RT+"={'record':{},'node':{},'tag':{},'enum':{}};\n"; RT += '.';
		wc += format.map(function(o){
			var code = "";
			if(o == null) return "// FIXME: null";
			if(o instanceof node.Comment){
				return "// " + o.value;
			}
			if(o instanceof node.Tag){
				tags[o.name] = o.value; tagInverse[o.value] = o.name;
				return RT+"tag."+o.name+" = "+o.value+";";
			}
			if(o instanceof node.TagOffset){
				tagInverse[tags[o.base] + o.offset] = o.name;
				return RT+"tag."+o.name+" = "+(tags[o.base] + o.offset)+";";
			}
			if(o instanceof node.Node){
				code += RT+"node."+o.name+" = function Node_"+o.name+"(){\n";
				code += "\tthis.name = \""+o.name+"\"; this.attr = {};\n";
				code += o.schema.map(function(nodeType){
					return "this.attr."+nodeType.name+" = "+(nodeType.options.default?"\""+nodeType.options.default+"\"":'null')+";";
				}).map(function(s){return '\t'+s+'\n';}).join('');
				code += "};";
				return code;
			}
			if(o instanceof node.Record){
				var offset = {'value': 0, 'add': function(v){
					if(typeof this.value == 'number'){
						this.value += v; return '';
					}
					var code = ' ';
					code += this.value+'+='+v+';';
					return code;
				}, 'toObj': function(){
					var code = "";
					if(typeof this.value == 'number'){
						code = "var offset={'value':"+this.value+"};";
						this.value = 'offset';
					}
					return code;
				}};
				code += RT+"record."+o.name+" = function Record_"+o.name+"(data){\n";
				code += "\tvar tmp; this.data = data;\n";
				code += o.schema.map(function(element){
					var c;
					if(element instanceof node.SimpleType){
						return simpleTypeCode("this", element, offset);
					}
					if(element instanceof node.Group){
						c = "this."+element.name+" = {};\n\t";
						c += element.values.map(function(e){
							return simpleTypeCode("this."+element.name, e, offset);
						}).join('\n\t');
						return c;
					}
					if(element instanceof node.Array){
						c = "this."+element.name+" = [];"+offset.toObj()+"\n";
						c += "\tfor(tmp=0;tmp<"+element.length+";tmp++){\n";
						c += "\t\tthis."+element.name+"[tmp] = {};\n";
						c += "\t\t"+element.type.map(function(e){
							return simpleTypeCode("this."+element.name+"[tmp]", e, offset);
						}).join('\n\t\t')+"\n";
						c += "\t}";
						return c;
					}
					if(element instanceof node.Script){
						c = offset.toObj()+' (function(){'+element.script.trim()+'}());';
						return c;
					}
					return "// FIXME: unprocessed type";
				}).map(function(s){return '\t'+s+'\n';}).join('');
				code += "};";
				return code;
			}
			return "// TODO: Process below object.\n/*\n"+o.toString()+"\n*/";
		}).join('\n')+'\n';
		wc += RT+"tag.table = "+JSON.stringify(tagInverse)+";";
		return wc;
	};

	parser.node = node;
%}

%lex
%%

"{{"([^\}]|"}"[^\}])+"}}"	return "SCRIPT";

\t\t	return "TWO_TABS";
\t	return "TAB";
"## "([^\n]+)	/* skip file comments */;
"# "([^\n]+)	return "COMMENT";

(" "|\r|\n)+ /* skip whitespaces */

\"([^\"]+)\"	return "QUOTED_STRING";

"String"	return "String";
"Int"	return "Int";
"Boolean"	return "Boolean";

"Array"	return "Array";
"Byte"	return "Byte";
"Word"	return "Word";
"DWord"	return "DWord";
"WChar"	return "WChar";
"WString"	return "WString";
"HWPUnit"	return "HWPUnit";
"SHWPUnit"	return "SHWPUnit";

"UInt8"	return "UInt8";
"UInt16"	return "UInt16";
"UInt32"	return "UInt32";
"Int8"	return "Int8";
"Int16"	return "Int16";
"Int32"	return "Int32";
"ColorRef"	return "ColorRef";

"ByteStream"	return "ByteStream";
"Bits"	return "Bits";
"Group"	return "Group";

"record"	return "RECORD";
"type"	return "TYPE";
"enum"	return "ENUM";
"node"	return "NODE";
"root"	return "ROOT";
"tago"	return "TAG_OFFSET";
"tag"	return "TAG";

"="	return "=";
":"	return ":";
"~"	return "~";

[0-9]+	return "INTEGER";
[A-Za-z0-9_\-]+	return "TOKEN";

<<EOF>>	return "EOF";

/lex

%start entry_point
%%

type_node
	: String
	| Int
	| Boolean
	;

type_record
	: Byte | Word | DWord
	| WChar | WString
	| HWPUnit | SHWPUnit
	| UInt8 | UInt16 | UInt32
	| Int8 | Int16 | Int32
	| ColorRef
	;

type_record_array_type
	: Array ":" TOKEN {$$ = $3;}
	| Array ":" INTEGER {$$ = +$3;}
	;

type_record_bytestream_type
	: ByteStream ":" TOKEN {$$ = $3;}
	| ByteStream ":" INTEGER {$$ = +$3;}
	;

entry_point
	: format	{return generateCode($1);}
	;

format
	: element format	{$$ = [$1].concat($2);}
	| EOF	{$$ = [];}
	;

element
	: def_enum {$$ = $1;}
	| def_node {$$ = $1;}
	| def_tag {$$ = $1;}
	| def_tago {$$ = $1;}
	| def_record {$$ = $1;}
	| COMMENT {$$ = new node.Comment($1);}
	| ROOT TOKEN {$$ = new node.Root($2);}
	;

def_enum
	: ENUM TOKEN {$$ = null;}
	;

def_node
	: NODE TOKEN {$$ = new node.Node($2, []);}
	| NODE TOKEN def_node_inner {$$ = new node.Node($2, $3);}
	;

def_node_inner
	: def_node_element def_node_inner {$$ = [$1].concat($2);}
	| def_node_element {$$ = [$1];}
	;

def_node_element
	: TAB type_node TOKEN {$$ = new node.NodeType($2, $3, []);}
	| TAB type_node TOKEN def_node_element_options {$$ = new node.NodeType($2, $3, $4);}
	;

def_node_element_options
	: def_node_element_option def_node_element_options {$$ = [$1].concat($2);}
	| def_node_element_option {$$ = [$1];}
	;

def_node_element_option
	: TOKEN "=" TOKEN {$$ = [$1, $3];}
	| TOKEN "=" QUOTED_STRING {$$ = [$1, $3.slice(1,-1)];}
	;

def_tag
	: TAG TOKEN INTEGER	{$$ = new node.Tag($2, $3);}
	;

def_tago
	: TAG_OFFSET TOKEN INTEGER TOKEN {$$ = new node.TagOffset($4, $2, $3);}
	;

def_record
	: RECORD TOKEN {$$ = new node.Record($2, []);}
	| RECORD TOKEN def_record_inner	{$$ = new node.Record($2, $3);}
	;

def_record_inner
	: def_record_element def_record_inner {$$ = [$1].concat($2);}
	| def_record_element {$$ = [$1];}
	;

def_record_element
	: TAB def_record_simpletype {$$ = $2;}
	| TAB def_record_group {$$ = $2;}
	| TAB def_record_array {$$ = $2;}
	| TAB def_record_bytestream {$$ = $2;}
	;

def_record_simpletype
	: type_record TOKEN {$$ = new node.SimpleType($1, $2);}
	| SCRIPT {$$ = new node.Script($1.slice(2,-2));}
	;

def_record_group
	: Group TOKEN def_record_group_inner {$$ = new node.Group($2, $3);}
	;

def_record_group_inner
	: def_record_group_element def_record_group_inner {$$ = [$1].concat($2);}
	| def_record_group_element {$$ = [$1];}
	;

def_record_group_element
	: TWO_TABS def_record_simpletype {$$ = $2;}
	;

def_record_array
	: type_record_array_type TOKEN def_record_group_inner {$$ = new node.Array($3, $1, $2);}
	;

def_record_bytestream
	: type_record_byptestream_type TOKEN {$$ = new node.ByteStream($1, $2);}
	;
