#scan
====
Implements the scan function for the D language

## Installation Notes
-------
Use dub

## Example
-------
```D
#!/usr/bin/env rdmd

import scan;

void main()
{
	import std.algorithm.comparison : cmp;

	int[] x = [1, 2, 5, 9];
	
	alias f = (a, b) => sum([a, b]);
	
	auto a = scan!(f)(x);
	assert(cmp(a, [1, 3, 8, 17]) == 0);
	
	auto b = cumsum(x);
	assert(cmp(b, [1, 3, 8, 17]) == 0);
	
	auto c = cumprod(x);
	assert(cmp(c, [1, 2, 10, 90]) == 0);
}
