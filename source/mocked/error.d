module mocked.error;

import std.exception;

final class ExpectationViolationError : Error
{
    mixin basicExceptionCtors;
}

final class ExpectationViolationException : Exception
{
    mixin basicExceptionCtors;
}
