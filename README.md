#scan
====
Implements the scan function for the D language to provide intermediate
calculations for std.algorithm's fold.

Also implements cumulative sum and product.

## Installation Notes
-------
Using dub, add `"scan": "~>=0.1.0",` to the dependencies section of dub.json
file (or relevant adjustments for dub.sdl).


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
