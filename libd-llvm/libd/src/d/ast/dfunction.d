module d.ast.dfunction;

import d.ast.base;
import d.ast.declaration;
import d.ast.dscope;
import d.ast.expression;
import d.ast.statement;
import d.ast.type;

/**
 * Function Declaration
 */
class FunctionDeclaration : ExpressionSymbol {
	Type returnType;		// TODO: remove this, redundant information.
	Parameter[] parameters;
	bool isVariadic;
	BlockStatement fbody;
	
	NestedScope dscope;
	
	this(Location location, string name, Type returnType, Parameter[] parameters, bool isVariadic, BlockStatement fbody) {
		this(location, name, "D", returnType, parameters, isVariadic, fbody);
	}
	
	this(Location location, string name, string linkage, Type returnType, Parameter[] parameters, bool isVariadic, BlockStatement fbody) {
		super(location, name, new FunctionType(location, linkage, returnType, parameters, isVariadic));
		
		this.name = name;
		this.linkage = linkage;
		this.returnType = returnType;
		this.parameters = parameters;
		this.isVariadic = isVariadic;
		this.fbody = fbody;
	}
	/*
	invariant() {
		auto funType = cast(FunctionType) type;
		
		assert(funType && funType.linkage == linkage);
	}
	*/
}

/**
 * Constructor Declaration
 */
class ConstructorDeclaration : Declaration {
	Parameter[] parameters;
	BlockStatement fbody;
	
	this(Location location, Parameter[] parameters, bool isVariadic, BlockStatement fbody) {
		super(location);
		
		this.parameters = parameters;
		this.fbody = fbody;
	}
	
	@property
	final string name() const {
		return "__ctor";
	}
}

/**
 * Destructor Declaration
 */
class DestructorDeclaration : Declaration {
	Parameter[] parameters;
	BlockStatement fbody;
	
	this(Location location, Parameter[] parameters, bool isVariadic, BlockStatement fbody) {
		super(location);
		
		this.parameters = parameters;
		this.fbody = fbody;
	}
	
	@property
	final string name() const {
		return "__dtor";
	}
}

/**
 * Function types
 */
class FunctionType : Type {
	Type returnType;
	Parameter[] parameters;
	bool isVariadic;
	
	string linkage;
	
	this(Location location, string linkage, Type returnType, Parameter[] parameters, bool isVariadic) {
		super(location);
		
		this.returnType = returnType;
		this.parameters = parameters;
		this.isVariadic = isVariadic;
		
		this.linkage = linkage;
	}
	
	override bool opEquals(const Type t) const {
		if(auto p = cast(FunctionType) t) {
			return this.opEquals(p);
		}
		
		return false;
	}
	
	bool opEquals(const FunctionType t) const {
		if(isVariadic != t.isVariadic) return false;
		if(linkage != t.linkage) return false;
		
		if(returnType != t.returnType) return false;
		if(parameters.length != t.parameters.length) return false;
		
		import std.range;
		foreach(p1, p2; lockstep(parameters, t.parameters)) {
			if(p1.type != p2.type) return false;
		}
		
		return true;
	}
}

/**
 * Delegate types
 */
class DelegateType : Type {
	Type returnType;
	Parameter context;
	Parameter[] parameters;
	bool isVariadic;
	
	string linkage;
	
	this(Location location, string linkage, Type returnType, Parameter context, Parameter[] parameters, bool isVariadic) {
		super(location);
		
		this.returnType = returnType;
		this.context = context;
		this.parameters = parameters;
		this.isVariadic = isVariadic;
		
		this.linkage = linkage;
	}
	
	override bool opEquals(const Type t) const {
		if(auto p = cast(DelegateType) t) {
			return this.opEquals(p);
		}
		
		return false;
	}
	
	bool opEquals(const DelegateType t) const {
		if(isVariadic != t.isVariadic) return false;
		if(linkage != t.linkage) return false;
		
		if(returnType != t.returnType) return false;
		if(context != t.context) return false;
		
		if(parameters.length != t.parameters.length) return false;
		
		import std.range;
		foreach(p1, p2; lockstep(parameters, t.parameters)) {
			if(p1.type != p2.type) return false;
		}
		
		return true;
	}
}

/**
 * Function and delegate parameters.
 */
class Parameter : ExpressionSymbol {
	bool isReference;
	
	this(Location location, Type type) {
		this(location, "", type);
	}
	
	this(Location location, string name, Type type) {
		super(location, name, type);
	}
	
	invariant() {
		assert(type !is null, "A parameter must have a type.");
	}
}

class InitializedParameter : Parameter {
	Expression value;
	
	this(Location location, string name, Type type, Expression value) {
		super(location, name, type);
		
		this.value = value;
	}
}
