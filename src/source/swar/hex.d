module source.swar.hex;

/**
 * Check we have enough digits in front of us to use SWAR.
 */
bool startsWithHexDigits(uint N)(string s) {
	import std.format;
	static assert(
		N == 2 || N == 4 || N == 8,
		format!"startsWithHexDigits only supports size 2, 4 and 8, not %d."(N)
	);

	if (s.length < N) {
		return false;
	}

	import std.meta;
	alias T = AliasSeq!(ushort, uint, ulong)[N / 4];

	import source.swar.util;
	auto v = read!T(s);

	// Set the high bit if the character isn't between '0' and '9'.
	auto lessThan0 = v - cast(T) 0x3030303030303030;
	auto moreThan9 = v + cast(T) 0x4646464646464646;

	// Set the high bit if the character isn't between 'a' and 'f'.
	auto hv = v | cast(T) 0x2020202020202020;
	auto lessThanA = (cast(T) 0xe0e0e0e0e0e0e0e0) - hv;
	auto moreThanF = hv + cast(T) 0x1919191919191919;

	// Combine
	auto c = (lessThan0 | moreThan9) & (lessThanA | moreThanF);

	// Check that none of the high bits are set.
	enum T Mask = 0x8080808080808080 & T.max;
	return (c & Mask) == 0;
}

unittest {
	static check0(string s) {
		assert(!startsWithHexDigits!2(s), s);
		assert(!startsWithHexDigits!4(s), s);
		assert(!startsWithHexDigits!8(s), s);
	}

	static check2(string s) {
		assert(startsWithHexDigits!2(s), s);
		assert(!startsWithHexDigits!4(s), s);
		assert(!startsWithHexDigits!8(s), s);
	}

	static check4(string s) {
		assert(startsWithHexDigits!2(s), s);
		assert(startsWithHexDigits!4(s), s);
		assert(!startsWithHexDigits!8(s), s);
	}

	static check8(string s) {
		assert(startsWithHexDigits!2(s), s);
		assert(startsWithHexDigits!4(s), s);
		assert(startsWithHexDigits!8(s), s);
	}

	check0("");

	// Naive implementation for correcteness.
	static bool isHexChar(char c) {
		if ('0' <= c && c <= '9') {
			return true;
		}

		if ('a' <= c && c <= 'f') {
			return true;
		}

		if ('A' <= c && c <= 'F') {
			return true;
		}

		return false;
	}

	// Test all combinations of 2 characters.
	foreach (char c0; 0 .. 256) {
		immutable char[1] s0 = [c0];
		check0(s0[]);

		auto isC0Hex = isHexChar(c0);
		foreach (char c1; 0 .. 256) {
			immutable char[2] s1 = [c0, c1];

			auto isC1Hex = isHexChar(c1);
			if (isC0Hex && isC1Hex) {
				check2(s1[]);
			} else {
				check0(s1[]);
			}

			static immutable char[] Chars = ['0', '9', 'a', 'f', 'A', 'F'];
			foreach (char c3; Chars) {
				foreach (char c4; Chars) {
					immutable char[4] s2 = [c0, c1, c3, c4];
					immutable char[4] s3 = [c4, c3, c1, c0];

					immutable char[8] s4 = [c0, c1, c0, c1, c0, c1, c3, c4];
					immutable char[8] s5 = [c4, c3, c3, c4, c3, c4, c1, c0];

					if (isC0Hex && isC1Hex) {
						check4(s2[]);
						check4(s3[]);
						check8(s4[]);
						check8(s5[]);
					} else {
						check0(s2[]);
						check2(s3[]);
						check0(s4[]);
						check4(s5[]);
					}
				}
			}
		}
	}
}

/**
 * Parse hexadecimal numbers using SWAR.
 *
 * http://0x80.pl/notesen/2014-10-09-pext-convert-ascii-hex-to-num.html
 * Archive: https://archive.ph/dpMxo
 */
private auto loadBuffer(T)(string s) in(s.length >= T.sizeof) {
	// v = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']
	auto v = *(cast(T*) s.ptr);

	/**
	 * For '0' to '9', the lower bits are what we are looking for.
	 * For letters, we get 'a'/'A'=1, 'b'/'B'=2, etc...
	 * So we add 9 whenever a letter is dected.
	 */
	auto base = v & cast(T) 0x0f0f0f0f0f0f0f0f;
	auto letter = v & cast(T) 0x4040404040404040;
	auto fixup = letter >> 3 | letter >> 6;

	// v = [a, b, c, d, e, f, g, h]
	return base + fixup;
}

ubyte parseHexDigits(T : ubyte)(string s) in(s.length >= 2) {
	auto v = loadBuffer!ushort(s);
	return ((v << 4) | (v >> 8)) & 0xff;
}

unittest {
	foreach (s, v; [
		"00" : 0x00,
		"99" : 0x99,
		"aa" : 0xaa,
		"ff" : 0xff,
		"AA" : 0xaa,
		"FF" : 0xff,
		"42" : 0x42,
		"3a" : 0x3a,
		"a0" : 0xa0,
		"cd" : 0xcd,
		"7F" : 0xc0,
		"7F" : 0x7f,
		"aB" : 0xab,
		"fE" : 0xfe
	]) {
		assert(startsWithHexDigits!2(s), s);
		assert(parseHexDigits!ubyte(s) == v, s);
	}
}

ushort parseHexDigits(T : ushort)(string s) in(s.length >= 4) {
	// v = [a, b, c, d]
	auto v = loadBuffer!uint(s);

	// v = [ba, dc]
	v |= v << 12;
	v &= 0xff00ff00;

	// dcba
	v |= v >> 24;
	return v & 0xffff;
}

unittest {
	foreach (s, v; [
		"0000" : 0x0000,
		"9999" : 0x9999,
		"aaaa" : 0xaaaa,
		"ffff" : 0xffff,
		"AAAA" : 0xaaaa,
		"FFFF" : 0xffff,
		"1234" : 0x1234,
		"abcd" : 0xabcd,
		"f00d" : 0xf00d,
		"beef" : 0xbeef,
		"C0DE" : 0xc0de,
		"F1ac" : 0xf1ac,
	]) {
		assert(startsWithHexDigits!4(s), s);
		assert(parseHexDigits!ushort(s) == v, s);
	}
}

uint parseHexDigits(T : uint)(string s) in(s.length >= 8) {
	// v = [a, b, c, d, e, f, g, h]
	auto v = loadBuffer!ulong(s);

	// v = [ba, dc, fe, hg]
	v |= v << 12;

	// a = [fe00ba, fe]
	auto a = (v >> 24) & 0x000000ff000000ff;
	a |= a << 48;

	// b = [hg00dc00, hg00]
	auto b = v & 0x0000ff000000ff00;
	b |= b << 48;

	// hgfedcba
	return (a | b) >> 32;
}

unittest {
	foreach (s, v; [
		"00000000" : 0x00000000,
		"99999999" : 0x99999999,
		"aaaaaaaa" : 0xaaaaaaaa,
		"ffffffff" : 0xffffffff,
		"AAAAAAAA" : 0xaaaaaaaa,
		"FFFFFFFF" : 0xffffffff,
		"12345678" : 0x12345678,
		"abcdef09" : 0xabcdef09,
		"DeadC0de" : 0xdeadc0de,
		"BAAAAAAD" : 0xbaaaaaad,
		"feedf00d" : 0xfeedf00d,
		"0D15EA5E" : 0x0d15ea5e,
	]) {
		assert(startsWithHexDigits!8(s), s);
		assert(parseHexDigits!uint(s) == v, s);
	}
}