module scan;

import std.array;
import std.traits : Select, Unqual;
import std.range.primitives : isInputRange, ElementType, ForeachType;

import std.stdio : writeln;

version(unittest)
{
	import std.algorithm : sum, cmp;
	import std.math : approxEqual;
	import std.stdio : writeln;
}

private struct scanResult(bool mustInitialize, alias fun, Range, 
						  E = Select!(isInputRange!Range, 
									  ElementType!Range, 
									  ForeachType!Range))
{
	alias R = Unqual!Range;
	import std.range.primitives : isBidirectionalRange, isRandomAccessRange,
								  isInfinite, hasLength, isForwardRange,
								  hasSlicing;
								  
    R _input;
	private E _previous;
	
	this(R input)
	{
		_input = input;
	}
	
	this(R input, E seed)
	{
		import std.algorithm.internal : algoFormat;
		import std.traits : fullyQualifiedName;
		
		static assert(!is(typeof(fun(seed, _input.front))) || 
					  is(typeof(seed = fun(seed, _input.front))),
						algoFormat("Incompatible function/seed/element: %s/%s/%s", 
							fullyQualifiedName!fun, seed.stringof, E.stringof));
			
		_input = input;
		_previous = seed;
	}
	
    static if (!mustInitialize)
	{
		@property auto ref front()
		{
			assert(!_input.empty, "Cannot front an empty range");
			
			return fun(_previous, _input.front);
		}

		static if (hasSlicing!R)
		{
			static if (is(typeof(_input[ulong.max .. ulong.max])))
				private alias opSlice_t = ulong;
			else
				private alias opSlice_t = uint;

			static if (hasLength!R)
			{
				auto opSlice(opSlice_t low, opSlice_t high)
				{
					import std.range : take;
					import std.algorithm.iteration : fold;
				
						E slide_seed = _input.take(low).fold!(fun)(_previous);
						return typeof(this)(_input[low .. high], slide_seed);
					
				}
			}
			else static if (is(typeof(_input[opSlice_t.max .. $])))
			{
				struct DollarToken{}
				enum opDollar = DollarToken.init;
				
				auto opSlice(opSlice_t low, DollarToken)
				{
					import std.range : take;
					import std.algorithm.iteration : fold;
					
						E slide_seed = _input.take(low).fold!(fun)(_previous);
						return typeof(this)(_input[low .. $], slide_seed);
				}

				auto opSlice(opSlice_t low, opSlice_t high)
				{
					import std.range : take;

					return this[low .. $].take(high - low);
				}
			}
		}
	}
	else static if (mustInitialize)
	{
		private bool _initialized = false;
		
		@property auto ref front()
		{
			assert(!_input.empty, "Cannot front an empty range");
			
			if (!_initialized)
			{
				_initialized = true;
				
				E _front;

				if (!(_previous is E.init)) //this is included in case opSlice 
											//needs a seed
				{
					
					_front = fun(_previous, _input.front);
				}
				else
				{
					_front = _input.front;
				}
				return _front;
			}
			else
			{
				if (!(_previous is E.init))
				{
					return fun(_previous, _input.front);
				}
				else
				{
					return _input.front;
				}
			}
		}
		
		//Specialized function required due to the way that front is handled
		static if (hasSlicing!R)
		{
			static if (is(typeof(_input[ulong.max .. ulong.max])))
				private alias opSlice_t = ulong;
			else
				private alias opSlice_t = uint;

			static if (hasLength!R)
			{
				auto opSlice(opSlice_t low, opSlice_t high)
				{
					import std.range : take;
					import std.algorithm.iteration : fold;
				
					if (_input.take(low).empty)
					{
						return typeof(this)(_input[low .. high], _previous);
					}
					else
					{
						E slide_seed = _input.take(low).fold!(fun)(_previous);
						return typeof(this)(_input[low .. high], slide_seed);
					}
				}
			}
			else static if (is(typeof(_input[opSlice_t.max .. $])))
			{
				struct DollarToken{}
				enum opDollar = DollarToken.init;
				
				auto opSlice(opSlice_t low, DollarToken)
				{
					import std.range : take;
					import std.algorithm.iteration : fold;
					
					if (_input.take(low).empty)
					{
						return typeof(this)(_input[low .. $], _previous);
						//_previous is used as a seed in the case of _input
						//being popFronted
					}
					else
					{
						E slide_seed = _input.take(low).fold!(fun)(_previous);
						return typeof(this)(_input[low .. $], slide_seed);
					}
				}

				auto opSlice(opSlice_t low, opSlice_t high)
				{
					import std.range : take;

					return this[low .. $].take(high - low);
				}
			}
		}
	}

	void popFront()
	{
		_previous = this.front;
		_input.popFront();
	}
	
	static if (isBidirectionalRange!R)
	{
		@property auto ref back()()
		{
			import std.algorithm.iteration : fold;
		
			return _input.fold!(fun)(_previous);
		}
	
		void popBack()()
		{
			_input.popBack();
		}
	}
	
	static if (isInfinite!R)
	{
		enum bool empty = false;
	}
	else
	{
		@property bool empty()
		{
			return _input.empty;
		}
	}
	
	static if (isRandomAccessRange!R)
	{
		static if (is(typeof(_input[ulong.max])))
			private alias opIndex_t = ulong;
		else
			private alias opIndex_t = uint;

		auto ref opIndex(opIndex_t index)
		{
			import std.range : take;
			import std.algorithm.iteration : fold;
			
			return _input.take(index + 1).fold!(fun)(_previous);
		}
	}

	static if (hasLength!R)
	{
		@property auto length()
		{
			return _input.length;
		}

		alias opDollar = length;
	}

	static if (isForwardRange!R)
    {
		@property auto save()
		{
			return this;
		}
    }
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(true, f, int[])(x);
	assert(r.front == 1);
	assert(r.front == 1); //front stability test
	r.popFront;
	assert(r.front == 3);
	assert(r.front == 3); //front stability test
	r.popFront;
	assert(r.front == 8);
	r.popFront;
	assert(r.front == 17);
	
	assert(!r.empty);
	r.popFront;
	assert(r.empty);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(true, f, int[])(x);
	r.popFront;
	assert(r.front == 3);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 0);
	assert(r.front == 1);
	assert(r.front == 1); //front stability test
	r.popFront;
	assert(r.front == 3);
	assert(r.front == 3); //front stability test
	r.popFront;
	assert(r.front == 8);
	r.popFront;
	assert(r.front == 17);
	
	assert(!r.empty);
	r.popFront;
	assert(r.empty);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 1);
	assert(r.front == 2);
	assert(r.front == 2); //front stability test
	r.popFront;
	assert(r.front == 4);
	assert(r.front == 4); //front stability test
	r.popFront;
	assert(r.front == 9);
	r.popFront;
	assert(r.front == 18);
	
	assert(!r.empty);
	r.popFront;
	assert(r.empty);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x,0);
	r.popFront;
	assert(r.front == 3);
}

@safe unittest
{
	float[] x = [0.1, -0.1, 0.1, -0.1];
	alias f = (a, b) => a * b;

	auto r = scanResult!(true, f, float[])(x);

	assert(approxEqual(r, [0.1, -0.01, -0.001, 0.0001]));
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => a + b; //switching to a + b so that type of r.front is
							   //float, if using sum, it is double

	float seed = 0;
	auto r = scanResult!(false, f, int[], float)(x, seed);
	assert(r.front == 1f);
	assert(is(typeof(r.front) == float));
	assert(approxEqual(r, [1f, 3f, 8f, 17f]));
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => a * b;

	auto r = scanResult!(true, f, int[])(x);
	
	assert(cmp(r, [1, 2, 10, 90]) == 0);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(true, f, int[])(x);
	assert(r.back == 17);
	
	import std.algorithm.iteration : fold;
	assert(r.back == x.fold!(f));

	r.popFront();
	assert(r.back == x.fold!(f));
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 0);
	assert(r.back == 17);
	
	import std.algorithm.iteration : fold;
	assert(r.back == x.fold!(f));
	
	r.popFront();
	assert(r.back == x.fold!(f));
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 1);
	assert(r.back == 18);
	
	import std.algorithm.iteration : fold;
	assert(r.back == x.fold!(f)(1));
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(true, f, int[])(x);
	r.popBack();
	assert(cmp(r, [1, 3, 8]) == 0);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 0);
	r.popBack();
	assert(cmp(r, [1, 3, 8]) == 0);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(true, f, int[])(x);
	assert(r[0] == 1);
	assert(r[1] == 3);
	assert(r[2] == 8);
	assert(r[3] == 17);
	
	assert(r.length == 4);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(true, f, int[])(x);
	assert(r[2] == 8);
	r.popFront;
	assert(r[1] == 8);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 0);
	assert(r[0] == 1);
	assert(r[1] == 3);
	assert(r[2] == 8);
	assert(r[3] == 17);
	
	assert(r.length == 4);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 0);
	assert(r[2] == 8);
	r.popFront;
	assert(r[1] == 8);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(true, f, int[])(x);
	assert(cmp(r[0 .. 1], [1]) == 0);
	assert(cmp(r[0 .. 2], [1, 3]) == 0);
	assert(cmp(r[0 .. 3], [1, 3, 8]) == 0);
	assert(cmp(r[0 .. 4], [1, 3, 8, 17]) == 0);
	assert(cmp(r[0 .. $], [1, 3, 8, 17]) == 0);
	assert(cmp(r[1 .. 4], [3, 8, 17]) == 0);
	assert(cmp(r[2 .. 4], [8, 17]) == 0);
	assert(cmp(r[2 .. $], [8, 17]) == 0);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 0);
	assert(cmp(r[0 .. 1], [1]) == 0);
	assert(cmp(r[0 .. 2], [1, 3]) == 0);
	assert(cmp(r[0 .. 3], [1, 3, 8]) == 0);
	assert(cmp(r[0 .. 4], [1, 3, 8, 17]) == 0);
	assert(cmp(r[0 .. $], [1, 3, 8, 17]) == 0);
	assert(cmp(r[1 .. 4], [3, 8, 17]) == 0);
	assert(cmp(r[2 .. 4], [8, 17]) == 0);
	assert(cmp(r[2 .. $], [8, 17]) == 0);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(true, f, int[])(x);
	assert(cmp(r[0 .. 3], [1, 3, 8]) == 0);
	r.popFront;

	assert(cmp(r[0 .. 3], [3, 8, 17]) == 0);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 0);
	assert(cmp(r[0 .. 3], [1, 3, 8]) == 0);
	r.popFront;
	assert(cmp(r[0 .. 3], [3, 8, 17]) == 0);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(true, f, int[])(x);
	auto r2 = r.save;
	static assert (is(typeof(r2) == typeof(r)));
	assert(cmp(r, r2) == 0);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 0);
	auto r2 = r.save;
	static assert (is(typeof(r2) == typeof(r)));
	assert(cmp(r, r2) == 0);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	auto r = scanResult!(false, f, int[])(x, 1);
	auto r2 = r.save;
	static assert (is(typeof(r2) == typeof(r)));
	assert(cmp(r, r2) == 0);
}

private template fillAliasSeq(bool mustInitialize, R, E, f...)
{
	//See discussion at
	//https://forum.dlang.org/post/vemmxwitowsyiqkjfqor@forum.dlang.org

	import std.meta : AliasSeq;
	
	static if (f.length == 0) {
		alias fillAliasSeq = AliasSeq!();
	}
	else {
		alias fillAliasSeq = AliasSeq!(
								scanResult!(mustInitialize, f[0], R, E), 
								fillAliasSeq!(mustInitialize, R, E, f[1..$])
									   );
	}
}

unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => a + b;
	alias g = (a, b) => a * b;
	
	alias TL = fillAliasSeq!(false, int[], int, f, g);
}

/++
Provides intermediate steps for the homonym function (also known as 
$(D accumulate), $(D compress), $(D inject), or $(D foldl)) 
present in various programming languages of functional flavor. 

The call $(D scan!(fun)(range, seed)) returns a range of which 
elements are obtained by first assigning $(D seed) to an internal 
variable $(D result). Then, for each element $(D x) in $(D range), 
a call to $(D front) returns $(D fun(result, x)). Calling $(D popFront) 
also updates $(D result) with the previous value of $(D front).

The one-argument version $(D scan!(fun)(range)) works similarly, 
but it uses the first element of the range as the seed (the range 
must be non-empty).

Parameters:
    fun = one or more functions
    r = an input range
	seed = an initial seed (optional)
	
Returns:
    A range with $(D fun) applied to the seed value and the front of $(D r).
	
	If there is more than one $(D fun), the element type will be $(D Tuple) 
	containing one element for each $(D fun).

See_Also:
    $(WEB en.wikipedia.org/wiki/Fold_(higher-order_function), Fold (higher-order function))

    $(LREF fold) is equivalent to applying $(D back) to the result of scan.
+/
template scan(fun...)
	if (fun.length >= 1)
{
    import std.meta : staticMap;
	import std.functional : binaryFun;

    alias binfuns = staticMap!(binaryFun, fun);
	
    static if (fun.length > 1)
	{
        import std.typecons : tuple, isTuple;
	}

    auto scan(R)(R r)
		if (isInputRange!R)
    {
        import std.exception : enforce;
		import std.range.primitives : isInputRange, ElementType, ForeachType;
		import std.traits : Select;
		import std.algorithm.iteration : ReduceSeedType;
		
        alias E = Select!(isInputRange!R, ElementType!R, ForeachType!R);
        alias Args = staticMap!(ReduceSeedType!E, binfuns);

        static if (isInputRange!R)
        {
            enforce(!r.empty, "Cannot scan an empty input range w/o an explicit seed value.");
        }

		auto result = Args.init;
		
		return scanImpl!(true)(r, result);
    }

	auto scan(R, S...)(R r, S seed)
		if (isInputRange!R)
    {
        static if (fun.length == 1)
		{
            return scanPreImpl(r, seed);
		}
        else static if (fun.length > 1)
        {
			static if (S.length == 1)
			{
				import std.algorithm.internal : algoFormat;
				
				static assert(isTuple!(S[0]), algoFormat("Seed %s should be a 
														 Tuple", S.stringof));
				
				return scanPreImpl(r, seed[0].expand);
			}
			else static if (S.length == fun.length)
			{
				return scanPreImpl(r, seed);
			}
			else
			{
				assert(0, "S must be a tuple or match fun.length");
			}
        }
		else
		{
			assert(0, "Must provide some functions");
		}
    }

    private auto scanPreImpl(R, Args...)(R r, ref Args args)
    {
		import std.traits : Unqual;
	
        alias Result = staticMap!(Unqual, Args);
		
        static if (is(Result == Args))
		{
            alias result = args;
		}
        else
		{
            Result result = args;
		}
			
        return scanImpl!(false)(r, result);
    }

    private auto scanImpl(bool mustInitialize, R, Args...)(R r, ref Args args)
		if (isInputRange!R)
    {
        import std.algorithm.internal : algoFormat;
		
        static assert(Args.length == fun.length,
					  algoFormat("Seed %s does not have the correct amount of fields (should be %s)", 
			                     Args.stringof, fun.length));
        alias E = Select!(isInputRange!R, ElementType!R, ForeachType!R);


		
		static if (Args.length > 1)
		{
			import std.typecons : Tuple;
		
			alias TL = fillAliasSeq!(mustInitialize, R, E, binfuns);
			Tuple!(TL) result;
		}

		static if (mustInitialize)
		{
			static if (Args.length == 1)
			{
				return scanResult!(true, binfuns[0], R)(r);
			}
			else
			{
				foreach (i, f; binfuns)
				{
					result[i] = scanResult!(true, f, R)(r);
				}
			
				return result;
			}
		}
		else
		{
			static if (Args.length == 1)
			{
				return scanResult!(false, binfuns[0], R, Args)(r, args);
			}
			else
			{
				foreach (i, f; binfuns)
				{
					result[i] = scanResult!(false, f, R, Args[i])(r, args[i]);
				}
			
				return result;
			}
		}
    }
}

///
@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => sum([a, b]);

	assert(cmp(x.scan!(f), [1, 3, 8, 17]) == 0);
}

/**
Functions can be string lambdas.
*/
@safe unittest
{
	int[] x = [1, 2, 5, 9];

	assert(cmp(x.scan!("a+b"), [1, 3, 8, 17]) == 0);
}

@safe unittest
{
	float[] x = [1.0, 2.0, 5.0, 9.0];
	alias f = (a, b) => sum([a, b]);

	assert(approxEqual(x.scan!(f), [1.0, 3.0, 8.0, 17.0]));
}

unittest
{
	import std.experimental.ndslice : sliced;

	int[] a = [1, 2, 5, 9];
	auto x = a.sliced(4);
	alias f = (a, b) => sum([a, b]);

	assert(cmp(x.scan!(f), [1, 3, 8, 17]) == 0);
}

unittest
{
	import std.experimental.ndslice : sliced, byElement, pack;

	int[] a = [1, 2, 5, 9];
	auto x = a.sliced(2, 2);
	alias f = (a, b) => sum([a, b]);
	
	assert(cmp(x.byElement.scan!(f), [1, 3, 8, 17]) == 0);
	
	auto y = x.pack!(1);
	writeln(y);
	//can't figure out how to get the slice to apply by dimension
	//auto y = x.scan!(f);
	//assert(cmp(y[0], [1, 3]) == 0);
	//assert(cmp(y[1], [5, 14]) == 0);
}

@safe unittest
{
	float[] x = [0.1, -0.1, 0.1, -0.1];
	float seed = 1;
	alias f = (a, b) => sum([a, b], seed);

	assert(approxEqual(x.scan!(f), [0.1, 1, 2.1, 3])); //note that f is not
															//applied to the 
															//first front
}

@safe unittest
{
	float[] x = [0.1, -0.1, 0.1, -0.1];
	float seed = 1;
	alias f = (a, b) => sum([a, b], seed);

	assert(approxEqual(x.scan!(f)(0.0), [1.1, 2, 3.1, 4]));//note that
																//is different
																//from above
																//due to seed
}

@safe unittest
{
	float[] x = [0.1, -0.1, 0.1, -0.1];
	alias f = (a, b) => (1 + a) * (1 + b) - 1;

	assert(approxEqual(x.scan!(f), [0.1, -0.01, 0.089, -0.0199]));
}

@safe unittest
{
	float[] x = [0.1, -0.1, 0.1, -0.1];
	alias f = (a, b) => a * b;

	auto y = x.scan!(f);

	assert(approxEqual(x.scan!(f), [0.1, -0.01, -0.001, 0.0001]));
}

@safe unittest
{
	int[] x = [1, 2, 3, 4, 5];
	alias f = (a, b) => sum([a, b]);

	assert(cmp(x.scan!(f)(6), [7, 9, 12, 16, 21]) == 0);
}

@safe unittest
{
	float[] x = [0.1, -0.1, 0.1, -0.1];
	alias f = (a, b) => a * b;

	assert(approxEqual(x.scan!(f)(0.0), [0, 0, 0, 0]));
}

@safe unittest
{
	float[] x = [0.1, -0.1, 0.1, -0.1];
	alias f = (a, b) => a * b;

	assert(approxEqual(x.scan!(f)(1.0), [0.1, -0.01, -0.001, 0.0001]));
}

/**
Multiple functions can be passed to $(D scan). In that case, the
element type of $(D map) is a tuple containing one element for each
function.
*/
@safe unittest
{
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => a + b;
	alias g = (a, b) => a * b;
	
	auto y = x.scan!(f, g);
	assert(cmp(y[0], [1, 3, 8, 17]) == 0);
	assert(cmp(y[1], [1, 2, 10, 90]) == 0);
}

@safe unittest
{
	int[] x = [1, 2, 5, 9];
	
	auto y = x.scan!("a + b", "a * b");
	assert(cmp(y[0], [1, 3, 8, 17]) == 0);
	assert(cmp(y[1], [1, 2, 10, 90]) == 0);
}


@safe unittest
{
	import std.typecons : tuple;
	
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => a + b;
	alias g = (a, b) => a * b;
	
	auto y = x.scan!(f, g)(tuple(0, 1));
	assert(cmp(y[0], [1, 3, 8, 17]) == 0);
	assert(cmp(y[1], [1, 2, 10, 90]) == 0);
}

@safe unittest
{
	import std.typecons : tuple;
	
	int[] x = [1, 2, 5, 9];
	alias f = (a, b) => a + b;
	alias g = (a, b) => a * b;
	
	auto y = x.scan!(f, g)(0, 1); //function not working for non-tuple
	assert(cmp(y[0], [1, 3, 8, 17]) == 0);
	assert(cmp(y[1], [1, 2, 10, 90]) == 0);
}

@safe unittest
{
	import std.algorithm.comparison: min, max;
	
	int[] x = [1, 2, 3, 4, 5];
	auto y = x.scan!(min, max);
	
	assert(cmp(y[0], [1, 1, 1, 1, 1]) == 0);
	assert(cmp(y[1], [1, 2, 3, 4, 5]) == 0);
}

@safe unittest
{	
	import std.algorithm.comparison: min, max;
	import std.typecons : tuple;
	
	int[] x = [1, 2, 3, 4, 5];
	auto y = x.scan!(min, max)(tuple(0, 7));
	
	assert(cmp(y[0], [0, 0, 0, 0, 0]) == 0);
	assert(cmp(y[1], [7, 7, 7, 7, 7]) == 0);
}

@safe unittest
{	
	import std.algorithm.comparison: min, max;
	import std.typecons : tuple;
	
	int[] x = [1, 2, 3, 4, 5];
	auto y = x.scan!(min, max)(0, 7);
	
	assert(cmp(y[0], [0, 0, 0, 0, 0]) == 0);
	assert(cmp(y[1], [7, 7, 7, 7, 7]) == 0);
}

/++
Returns the cumulative sum of a range.

The sum at each point is calculated using the 
$(LREF std.algorithm.iteration.sum) function. 

Parameters:
    r = an input range
	seed = a seed to pass to sum (optional)
	
Returns:
    A range containing the cumulative sum. 

See_Also:
    $(WEB en.wikipedia.org/wiki/Prefix_sumn), Prefix Sum)
+/
auto cumsum(R, S...)(R r, S seed)
	if (isInputRange!R)
{
	static if (S.length == 0)
	{
		alias f = (a, b) => sum([a, b]);
		return r.scan!(f);
	}
	else static if (S.length == 1)
	{
		alias f = (a, b) => sum([a, b], seed);
		return r.scan!(f)(seed);
	}
	else
	{
		assert(0, "S must have length of 0 or 1");
	}
}

///
@safe unittest
{
	int[] x = [1, 2, 3, 4, 5];

	assert(cmp(cumsum(x), [1, 3, 6, 10, 15]) == 0);
	assert(cmp(cumsum(x, 0), [1, 3, 6, 10, 15]) == 0);
	assert(approxEqual(cumsum(x, 0f), [1.0, 3.0, 6.0, 10.0, 15.0]));
}

/++
Returns the cumulative product of a range.

Parameters:
    r = an input range
	seed = a seed to pass (optional). Note that when multiplying, it can be
		preferable to pass a 1, rather than a 0 as is common with summing.
	
Returns:
    A range containing the cumulative product. 

See_Also:
    $(WEB en.wikipedia.org/wiki/Prefix_sumn), Prefix Sum)
+/
auto cumprod(R, S...)(R r, S seed)
	if (isInputRange!R)
{
	alias f = (a, b) => a * b;

	static if (S.length == 0)
	{
		return scan!(f)(r);
	}
	else static if (S.length == 1)
	{
		return r.scan!(f)(seed);
	}
	else
	{
		assert(0, "S must have length of 0 or 1");
	}
}

///
@safe unittest
{
	float[] x = [0.1, -0.1, 0.1, -0.1];

	assert(approxEqual(cumprod(x), [0.1, -0.01, -0.001, 0.0001]));
}

@safe unittest
{
	float[] x = [0.1, -0.1, 0.1, -0.1];

	real seed = 1.0;
	auto y = cumprod(x, seed);
	
	real[] test = [0.1, -0.01, -0.001, 0.0001];
	
	assert(approxEqual(y, test));
}