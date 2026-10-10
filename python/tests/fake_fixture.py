import pytest

@pytest.fixture(autouse=True)
def fake_fixture():
    print(">>>>>>>>")
    fake1 = "fake"
    xx = 123
    # fake = (fake_fixturee, xx)
    yield fake1
    print("<<<<<<<<")

@pytest.mark.usefixtures("fake_fixture")
def test_fake_fixture():
    list_1 = ["python", 2, 3]
    try:
        list_1.index("java")
    except ValueError:
        print("fake")

    with pytest.raises(ValueError) as e:
        list_1.index("java")
    print(e.value)
    assert 'ValueError' in str(e)

    lst = [10,20,30,40,50,60,70,80]
    print(lst[::-1])
    print(lst[7::-1])
    print(lst[6::-1])
    print(lst[6::-2])