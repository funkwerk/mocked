module mocked.meta;

struct Maybe(Arguments...)
{
    private Arguments arguments = Arguments.init;
    private bool isNull_ = true;

    public static Maybe!Arguments opCall(Arguments arguments)
    {
        typeof(return) ret;

        ret.arguments = arguments;
        ret.isNull_ = false;

        return ret;
    }

    public void opAssign(Arguments arguments)
    {
        this.arguments = arguments;
        this.isNull_ = false;
    }

    public @property bool isNull()
    {
        return this.isNull_;
    }

    public @property ref Arguments[n] get(size_t n)()
    if (n < Arguments.length)
    in (!this.isNull())
    {
        return this.arguments[n];
    }
}
