# MockeD

![CI](https://github.com/funkwerk/mocked/workflows/CI/badge.svg)
[![License](https://img.shields.io/badge/license-MPL_2.0-blue.svg)](https://raw.githubusercontent.com/funkwerk/mocked/master/LICENSE)
[![codecov](https://codecov.io/gh/funkwerk/mocked/branch/master/graph/badge.svg)](https://codecov.io/gh/funkwerk/mocked)
[![Dub version](https://img.shields.io/dub/v/mocked.svg)](https://code.dlang.org/packages/mocked)
[![Dub downloads](https://img.shields.io/dub/dt/mocked.svg)](https://code.dlang.org/packages/mocked)

A mocking framework for the D programming language.

```d
import mocked;

class Dependency
{
    string authorOf(string phrase)
    {
        return null;
    }
}

enum string phrase = "[T]he meaning of a word is its use in the language.";
enum string expected = "L. Wittgenstein";

Mocker mocker;
auto builder = mocker.mock!Dependency;

builder.expect
    .authorOf("[T]he meaning of a word is its use in the language.")
    .returns(expected);

auto dependency = builder.getMock;

assert(dependency.authorOf(phrase) == expected);
```
