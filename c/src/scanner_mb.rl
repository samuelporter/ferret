/* scanner.rl -*-C-*- */
#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <wchar.h>
#include <wctype.h>
#include "global.h"
#include "internal.h"

static char *position_in_mb( const unsigned long *orig_wc,
                             const char *orig_mb,
                             const unsigned long *curr_wc )
{
    char          *mb = (char *)orig_mb;
    unsigned long *wc = (char *)orig_wc;

    while (wc < curr_wc)
    {
        char buf[MB_LEN_MAX];
        mb += wctomb(buf, *wc);
        ++wc;
    }

    return mb;
}

#define RET do {                        \
    *start   = position_in_mb(buf, in, ts); \
    *end     = position_in_mb(buf, in, te); \
    size_t __len = *end - *start - skip - trunc; \
    *len     = __len;                   \
    if (__len > out_size)               \
        __len = out_size;               \
     memcpy(out, *start + skip, __len);     \
     out[__len] = 0;                    \
     return;                            \
} while(0)

#define STRIP(c) do {                         \
    unsigned long *__p = ts;                  \
    unsigned long *__o = out;                 \
    unsigned long *__max = __p + out_size;    \
    for (; __p <= te && __p < __max; ++__p) { \
        if (*__p != c)                        \
            *__o++ = *__p;                    \
    }                                         \
    *__o = 0;                                 \
                                              \
    *start = position_in_mb(buf, in, ts);                              \
    *end   = position_in_mb(buf, in, te);                              \
    *len   = (char *)__o - (char *)out;                       \
    return;                                   \
} while(0)

%%{
    machine StdTokMb;
    alphtype unsigned long;
    include "src/wchar.rl";

    wdigit = '0' .. '9';

    u0   =
        0x041 .. 0x05a | 0x061 .. 0x07a | 0x0aa | 0x0b5 | 0x0ba |
        0x0c0 .. 0x0d6 | 0x0d8 .. 0x0f6 | 0x0f8 .. 0x0ff;
    u2   =
        0x200 .. 0x220 | 0x222 .. 0x233 | 0x250 .. 0x2ad | 0x2b0 .. 0x2b8 |
        0x2bb .. 0x2c1 | 0x2d0 .. 0x2d1 | 0x2e0 .. 0x2e4 | 0x2ee;
    u3   =
        0x345 | 0x37a | 0x386 | 0x388 .. 0x38a | 0x38c | 0x38e .. 0x3a1 |
        0x3a3 .. 0x3ce | 0x3d0 .. 0x3f5;
    u4   =
        0x400 .. 0x481 | 0x48a .. 0x4ce | 0x4d0 .. 0x4f5 | 0x4f8 .. 0x4f9;
    u5   =
        0x500 .. 0x50f | 0x531 .. 0x556 | 0x559 | 0x561 .. 0x587 |
        0x5d0 .. 0x5ea | 0x5f0 .. 0x5f2;
    u6   =
        0x621 .. 0x63a | 0x640 .. 0x64a | 0x660 .. 0x669 | 0x66e .. 0x66f |
        0x671 .. 0x6d3 | 0x6d5 | 0x6e5 .. 0x6e6 | 0x6f0 .. 0x6fc;
    u7   =
        0x710 | 0x712 .. 0x72c | 0x780 .. 0x7a5 | 0x7b1;
    u9   =
        0x905 .. 0x939 | 0x93d | 0x950 | 0x958 .. 0x961 | 0x966 .. 0x96f |
        0x985 .. 0x98c | 0x98f .. 0x990 | 0x993 .. 0x9a8 | 0x9aa .. 0x9b0 |
        0x9b2 | 0x9b6 .. 0x9b9 | 0x9dc .. 0x9dd | 0x9df .. 0x9e1 |
        0x9e6 .. 0x9f1;
    ua   =
        0xa05 .. 0xa0a | 0xa0f .. 0xa10 | 0xa13 .. 0xa28 | 0xa2a .. 0xa30 |
        0xa32 .. 0xa33 | 0xa35 .. 0xa36 | 0xa38 .. 0xa39 | 0xa59 .. 0xa5c |
        0xa5e | 0xa66 .. 0xa6f | 0xa72 .. 0xa74 | 0xa85 .. 0xa8b | 0xa8d |
        0xa8f .. 0xa91 | 0xa93 .. 0xaa8 | 0xaaa .. 0xab0 | 0xab2 .. 0xab3 |
        0xab5 .. 0xab9 | 0xabd | 0xad0 | 0xae0 | 0xae6 .. 0xaef;
    ub   =
        0xb05 .. 0xb0c | 0xb0f .. 0xb10 | 0xb13 .. 0xb28 | 0xb2a .. 0xb30 |
        0xb32 .. 0xb33 | 0xb36 .. 0xb39 | 0xb3d | 0xb5c .. 0xb5d |
        0xb5f .. 0xb61 | 0xb66 .. 0xb6f | 0xb83 | 0xb85 .. 0xb8a |
        0xb8e .. 0xb90 | 0xb92 .. 0xb95 | 0xb99 .. 0xb9a | 0xb9c |
        0xb9e .. 0xb9f | 0xba3 .. 0xba4 | 0xba8 .. 0xbaa |
        0xbae .. 0xbb5 | 0xbb7 .. 0xbb9 | 0xbe7 .. 0xbef;
    uc   =
        0xc05 .. 0xc0c | 0xc0e .. 0xc10 | 0xc12 .. 0xc28 | 0xc2a .. 0xc33 |
        0xc35 .. 0xc39 | 0xc60 .. 0xc61 | 0xc66 .. 0xc6f | 0xc85 .. 0xc8c |
        0xc8e .. 0xc90 | 0xc92 .. 0xca8 | 0xcaa .. 0xcb3 | 0xcb5 .. 0xcb9 |
        0xcde | 0xce0 .. 0xce1 | 0xce6 .. 0xcef;
    ud   =
        0xd05 .. 0xd0c | 0xd0e .. 0xd10 | 0xd12 .. 0xd28 | 0xd2a .. 0xd39 |
        0xd60 .. 0xd61 | 0xd66 .. 0xd6f | 0xd85 .. 0xd96 | 0xd9a .. 0xdb1 |
        0xdb3 .. 0xdbb | 0xdbd | 0xdc0 .. 0xdc6;
    ue   =
        0xe01 .. 0xe2e | 0xe30 .. 0xe3a | 0xe40 .. 0xe45 | 0xe47 .. 0xe4e |
        0xe50 .. 0xe59 | 0xe81 .. 0xe82 | 0xe84 | 0xe87 .. 0xe88 | 0xe8a |
        0xe8d | 0xe94 .. 0xe97 | 0xe99 .. 0xe9f | 0xea1 .. 0xea3 | 0xea5 |
        0xea7 | 0xeaa .. 0xeab | 0xead .. 0xeb0 | 0xeb2 .. 0xeb3 | 0xebd |
        0xec0 .. 0xec4 | 0xec6 | 0xed0 .. 0xed9 | 0xedc .. 0xedd;
    uf   =
        0xf00 | 0xf20 .. 0xf29 | 0xf40 .. 0xf47 | 0xf49 .. 0xf6a |
        0xf88 .. 0xf8b;
    u10  =
        0x1000 .. 0x1021 | 0x1023 .. 0x1027 | 0x1029 .. 0x102a |
        0x1040 .. 0x1049 | 0x1050 .. 0x1055 | 0x10a0 .. 0x10c5 |
        0x10d0 .. 0x10f8;
    u11  =
        0x1100 .. 0x1159 | 0x115f .. 0x11a2 | 0x11a8 .. 0x11f9;
    u12  =
        0x1200 .. 0x1206 | 0x1208 .. 0x1246 | 0x1248 | 0x124a .. 0x124d |
        0x1250 .. 0x1256 | 0x1258 | 0x125a .. 0x125d | 0x1260 .. 0x1286 |
        0x1288 | 0x128a .. 0x128d | 0x1290 .. 0x12ae | 0x12b0 |
        0x12b2 .. 0x12b5 | 0x12b8 .. 0x12be | 0x12c0 | 0x12c2 .. 0x12c5 |
        0x12c8 .. 0x12ce | 0x12d0 .. 0x12d6 | 0x12d8 .. 0x12ee |
        0x12f0 .. 0x12ff;
    u13  =
        0x1300 .. 0x130e | 0x1310 | 0x1312 .. 0x1315 | 0x1318 .. 0x131e |
        0x1320 .. 0x1346 | 0x1348 .. 0x135a | 0x1369 .. 0x1371 |
        0x13a0 .. 0x13f4;
    u14  =
        0x1401 .. 0x14ff;
    u16  =
        0x1600 .. 0x166c | 0x166f .. 0x1676 | 0x1681 .. 0x169a |
        0x16a0 .. 0x16ea | 0x16ee .. 0x16f0;
    u17  =
        0x1700 .. 0x170c | 0x170e .. 0x1711 | 0x1720 .. 0x1731 |
        0x1740 .. 0x1751 | 0x1760 .. 0x176c | 0x176e .. 0x1770 |
        0x1780 .. 0x17b3 | 0x17d7 | 0x17dc | 0x17e0 .. 0x17e9;
    u18  =
        0x1810 .. 0x1819 | 0x1820 .. 0x1877 | 0x1880 .. 0x18a8;
    u1e  =
        0x1e00 .. 0x1e9b | 0x1ea0 .. 0x1ef9;
    u1f  =
        0x1f00 .. 0x1f15 | 0x1f18 .. 0x1f1d | 0x1f20 .. 0x1f45 |
        0x1f48 .. 0x1f4d | 0x1f50 .. 0x1f57 | 0x1f59 | 0x1f5b | 0x1f5d |
        0x1f5f .. 0x1f7d | 0x1f80 .. 0x1fb4 | 0x1fb6 .. 0x1fbc | 0x1fbe |
        0x1fc2 .. 0x1fc4 | 0x1fc6 .. 0x1fcc | 0x1fd0 .. 0x1fd3 |
        0x1fd6 .. 0x1fdb | 0x1fe0 .. 0x1fec | 0x1ff2 .. 0x1ff4 |
        0x1ff6 .. 0x1ffc;
    u20  =
        0x2071 | 0x207f;
    u21  =
        0x2102 | 0x2107 | 0x210a .. 0x2113 | 0x2115 | 0x2119 .. 0x211d |
        0x2124 | 0x2126 | 0x2128 .. 0x212d | 0x212f .. 0x2131 |
        0x2133 .. 0x2139 | 0x213d .. 0x213f | 0x2145 .. 0x2149 |
        0x2160 .. 0x2183;
    u24  =
        0x249c .. 0x24e9;
    u30  =
        0x3005 .. 0x3007 | 0x3021 .. 0x3029 | 0x3031 .. 0x3035 |
        0x3038 .. 0x303c | 0x3041 .. 0x3096 | 0x309d .. 0x309f |
        0x30a1 .. 0x30fa | 0x30fc .. 0x30ff;
    u31  =
        0x3105 .. 0x312c | 0x3131 .. 0x318e | 0x31a0 .. 0x31b7 |
        0x31f0 .. 0x31ff;
    u4d  =
        0x4d00 .. 0x4db5;
    u9f  =
        0x9f00 .. 0x9fa5;
    ua4  =
        0xa400 .. 0xa48c;
    ud7  =
        0xd7a3;
    ufa  =
        0xfa00 .. 0xfa2d | 0xfa30 .. 0xfa6a;
    ufb  =
        0xfb00 .. 0xfb06 | 0xfb13 .. 0xfb17 | 0xfb1d | 0xfb1f .. 0xfb28 |
        0xfb2a .. 0xfb36 | 0xfb38 .. 0xfb3c | 0xfb3e | 0xfb40 .. 0xfb41 |
        0xfb43 .. 0xfb44 | 0xfb46 .. 0xfbb1 | 0xfbd3 .. 0xfbff;
    ufd  =
        0xfd00 .. 0xfd3d | 0xfd50 .. 0xfd8f | 0xfd92 .. 0xfdc7 |
        0xfdf0 .. 0xfdfb;
    ufe  =
        0xfe70 .. 0xfe74 | 0xfe76 .. 0xfefc;
    uff  =
        0xff10 .. 0xff19 | 0xff21 .. 0xff3a | 0xff41 .. 0xff5a |
        0xff66 .. 0xffbe | 0xffc2 .. 0xffc7 | 0xffca .. 0xffcf |
        0xffd2 .. 0xffd7 | 0xffda .. 0xffdc;
    u103 =
        0x10300 .. 0x1031e | 0x10330 .. 0x1034a;
    u104 =
        0x10400 .. 0x10425 | 0x10428 .. 0x1044d;
    u1d4 =
        0x1d400 .. 0x1d454 | 0x1d456 .. 0x1d49c | 0x1d49e .. 0x1d49f |
        0x1d4a2 | 0x1d4a5 .. 0x1d4a6 | 0x1d4a9 .. 0x1d4ac |
        0x1d4ae .. 0x1d4b9 | 0x1d4bb | 0x1d4bd .. 0x1d4c0 |
        0x1d4c2 .. 0x1d4c3 | 0x1d4c5 .. 0x1d4ff;
    u1d5 =
        0x1d500 .. 0x1d505 | 0x1d507 .. 0x1d50a | 0x1d50d .. 0x1d514 |
        0x1d516 .. 0x1d51c | 0x1d51e .. 0x1d539 | 0x1d53b .. 0x1d53e |
        0x1d540 .. 0x1d544 | 0x1d546 | 0x1d54a .. 0x1d550 |
        0x1d552 .. 0x1d5ff;
    u1d6 =
        0x1d600 .. 0x1d6a3 | 0x1d6a8 .. 0x1d6c0 | 0x1d6c2 .. 0x1d6da |
        0x1d6dc .. 0x1d6fa | 0x1d6fc .. 0x1d6ff;
    u1d7 =
        0x1d700 .. 0x1d714 | 0x1d716 .. 0x1d734 | 0x1d736 .. 0x1d74e |
        0x1d750 .. 0x1d76e | 0x1d770 .. 0x1d788 | 0x1d78a .. 0x1d7a8 |
        0x1d7aa .. 0x1d7c2 | 0x1d7c4 .. 0x1d7c9 | 0x1d7ce .. 0x1d7ff;
    u2a6 =
        0x2a600 .. 0x2a6d6;
    u2fa =
        0x2fa00 .. 0x2fa1d;

    walpha =
        'a' .. 'z' |
        'A' .. 'Z' |

        0x0100 .. 0x01ff   |
        0x1500 .. 0x15ff   |
        0x3400 .. 0x4cff   |
        0x4e00 .. 0x9eff   |
        0xa000 .. 0xa3ff   |
        0xac00 .. 0xd6ff   |
        0xf900 .. 0xf9ff   |
        0xfc00 .. 0xfcff   |
        0x20000 .. 0x2a5ff |
        0x2f800 .. 0x2f9ff |

        u0   | u2   | u3   | u4   | u5  | u6  | u7 |
        u9   | ua   | ub   | uc   | ud  | ue  | uf |
        u10  | u11  | u12  | u13  | u14 | u16 |
        u17  | u18  | u1e  | u1f  | u20 | u21 |
        u24  | u30  | u31  | u4d  | u9f | ua4 |
        ud7  | ufa  | ufb  | ufd  | ufe | uff |
        u103 | u104 | u1d4 | u1d5 |
        u1d6 | u1d7 | u2a6 | u2fa;


    walnum = wdigit | walpha;

    delim = space;
    token = walpha walnum*;
    punc  = [.,\/_\-];
    proto = 'http'[s]? | 'ftp' | 'file';
    urlc  = walnum | punc | [\@\:];

    main := |*

        #// Token, or token with possessive
        token           { RET; };
        token [\']      { trunc = 1; RET; };
        token [\'][sS]? { trunc = 2; RET; };

        #// Token with hyphens
        walnum+ ('-' walnum+)* { RET; };

        #// Company name
        token [\&\@] token* { RET; };

        #// URL
        proto [:][/]+ %{ skip = p - ts; } urlc+ [/] { trunc = 1; RET; };
        proto [:][/]+ %{ skip = p - ts; } urlc+     { RET; };
        walnum+[:][/]+ urlc+ [/] { trunc = 1; RET; };
        walnum+[:][/]+ urlc+     { RET; };

        #// Email
        walnum+ '@' walnum+ '.' walpha+ { RET; };

        #// Acronym
        (walpha '.')+ walpha { STRIP('.'); };

        #// Int+float
        [\-\+]?wdigit+            { RET; };
        [\-\+]?wdigit+ '.' wdigit+ { RET; };

        #// Ignore whitespace and other crap
        0 { return; };
        (any - walnum);

        *|;
}%%

%% write data nofinal;

static int mb_next_char(wchar_t *wchr, const char *s, mbstate_t *state)
{
    int num_bytes;
    if ((num_bytes = (int)mbrtowc(wchr, s, MB_CUR_MAX, state)) < 0) {
        const char *t = s;
        do {
            t++;
            ZEROSET(state, mbstate_t);
            num_bytes = (int)mbrtowc(wchr, t, MB_CUR_MAX, state);
        } while ((num_bytes < 0) && (*t != 0));
        num_bytes = t - s;
        if (*t == 0) *wchr = 0;
    }
    return num_bytes;
}

/* Function takes in a multibyte string, converts it to wide-chars and
   then tokenizes that. */
void frt_std_scan_mb(const char *in, size_t in_size,
                 char *out, size_t out_size,
                 char **start, char **end,
                 int *len)
{
    int cs, act;
    unsigned long *ts, *te = 0;

    %% write init;

    unsigned long buf[4096] = {0};
    unsigned long *bufp = buf;
    char *inp = (char *)in;
    mbstate_t state;
    ZEROSET(&state, mbstate_t);
    printf ("TRYING TO PARSE: '%s'\n", in);
    while (inp < (in + in_size) && bufp < (buf + sizeof(buf)/sizeof(*buf)))
    {
        if (!*inp)
            break;

        int n = mb_next_char((wchar_t *)bufp, inp, &state);
        if (n < 0)
        {
            printf ("Error parsing input\n");
            ++inp;
            continue;
        }

        /* We can break out early here on, say, a space XXX */
        inp += n;
        ++bufp;
    }

    printf ("parsed: %d\n", inp - in);
    wprintf (L"%ls\n", buf);
    printf ("%04x\n", buf[5]);

    unsigned long *p = (unsigned long *)buf;
    unsigned long *pe = 0;
    unsigned long *eof = pe;
    *len = 0;
    int skip = 0;
    int trunc = 0;

    %% write exec;

    if ( cs == StdTokMb_error )
    {
        fprintf(stderr, "PARSE ERROR\n" );
        return;
    }

    if ( ts )
    {
        fwprintf(stderr, L"STUFF LEFT: '%ls'\n", ts);
    }
}
