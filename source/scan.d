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