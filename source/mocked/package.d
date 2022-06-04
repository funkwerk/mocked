module mocked;

public import mocked.error : UnexpectedCallError, UnexpectedArgumentError,
       OutOfOrderCallError, ExpectationViolationException;
public import mocked.mocker : Configure, configure, Factory, Mocked, Mocker, Stubbed;
public import mocked.option : Comparator;
