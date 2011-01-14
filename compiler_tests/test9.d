//T compiles:yes
//T retval:0
// Tests strings and character literals, and string/pointer casts.

extern(C) size_t strlen(const char* s);

int main()
{
    char[] str = "test";
    if (str.length != 4) {
        return 1;
    }
    if (str[2] != 's') {
        return 2;
    }
    char* p = str;
    if(strlen(p) != str.length) {
        return 3;
    }
    return 0;
}

