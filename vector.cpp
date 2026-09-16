#include <cstddef>
#include <new>
#include <iostream>
#include <utility>
#include <tuple>
#include <initializer_list>

// NOTES:
// - prefer member initialization lists
// - prefer curly brace initialization (list initialization)
// - whether the `T&&` syntax means "RVALUE REFERENCE" or "FORWARDING REFERENCE" depends entirely on context
//   - if `T&&` appears as the parameter type of a function template with `typename T`, then it means
//     forwarding reference
//   - otherwise it's an rvalue reference
// - forwarding references are special because (1) they're universal and (2) they remember the original value
//   category of the passed argument

void sink(const int&); // sink 0
void sink(int&&);      // sink 1

template <typename T>
void pipe(T&& x)
{
    sink(std::forward<T>(x)); // conditional move
        // if `x` was an lvalue expression then it doesn't do anything
        // otherwise it moves `x`

    // the above is equivalent to:

    if (std::is_lvalue_reference_v<T>) { sink(x); }
    else                               { sink(std::move(x)); }
}

void test()
{
    pipe(0); // I want to get to sink 1 (`int&&` version)
        // NO SPECIAL RULE
        // 1. deduce `T` as `int`
        // 2. `T&&` becomes `int&&` after substitution

    int i;
    pipe(i); // I want to get to sink 0 (`const int&` version)
        // SPECIAL RULE
        // 1. deduce `T` as `int&` (weird)
        // 2. `T&&` becomes `int& &&` (disallowed)
        // 3. apply "reference collapsing" -> `int& &&` -> `int&` (lvalue is dominant)
}

// Special rule in the standard:
// - during template argument deduction, if an lvalue is passed to a `T&&` parameter
//   then `T` is deduced as an lvalue reference

template <typename T>
void normal(T& x) { }

void testNormal()
{
    int i;
    normal(i);
        // NO SPECIAL RULE
        // 1. `T` deduced as `int`
        // 2. `T&` becomes `int&`
}


std::vector<std::string> globalVec;

template <typename T>
void putInGlobalVec(T&& x)
{
    globalVec.push_back(std::forward<T>(x));
}

void test2()
{
    putInGlobalVec(std::string{"..."});
        // 1. bind temporary string to `x`
        // 2. inside `putInGlobalVec` we move `x` into `push_back` (by rvalue ref)
        // 3. `push_back` internally invokes `string(string&&)` (this is the "sink")

    std::string s{"..."};
    putInGlobalVec(s);
        // 1. bind non-temporary string to `x`
        // 2. inside `putInGlobalVec` we pass `x` into `push_back` (by lvalue ref)
        // 3. `push_back` internally invokes `string(const string&)` (this is the "sink")
}


template <typename T>
class Vector {
    // one std::initializer list constructor
    // rule of 5
    // push_back
    // resize
    // reserve
    // emplace back
    // pop_back
    // begin, end
    // .data()
    private:
        std::byte* d_data;
        size_t d_capacity;
        size_t d_size;

        [[nodiscard]] T* get_raw_elem_mutable(std::size_t i)
        {
            return reinterpret_cast<T*>(d_data + i * sizeof(T));
        }

        [[nodiscard]] const T* get_raw_elem_const(std::size_t i)
        {
            return reinterpret_cast<const T*>(d_data + i * sizeof(T));
        }

        [[nodiscard]] std::byte* allocate(std::size_t capacity)
        {
            return static_cast<std::byte*>(::operator new[](sizeof(T) * capacity, std::align_val_t{alignof(T)}));
        }

        void deallocate(std::byte* ptr)
        {
            ::operator delete[](ptr,  std::align_val_t{alignof(T)});
        }

    public:
        Vector() : d_data(nullptr), d_capacity(0), d_size(0) {}

        // copy constructor
        Vector(const Vector<T>& other) :
            d_data{allocate(other.d_size)},
            d_capacity{other.d_size},
            d_size{other.d_size}
        {

            // VR: this loop is making two copies per iteration
            for(size_t i = 0; i < d_size; i++) {
                new (get_raw_elem_mutable(i)) T(*other.get_raw_elem_const(i));
            }
        }

        // copy assigment operator
        Vector<T>& operator=(const Vector<T>& other) {
            if(this == &other) return *this;

            // clear old vector memory
            for(size_t i = 0; i < d_size; i++) {
                //     you could have an helper function to access the n-th element
                get_raw_elem_mutable(i)->~T();
            }

            // VR: delete doesn't need parentheses
            // VR: should also be `::operator delete`
            deallocate(d_data);

            d_capacity = other.d_size;
            d_size = other.d_size;

            // VR: not exception-safe

            // VR: ditto (alignment, extra copy)
            d_data = new std::byte[d_size * sizeof(T)];

            for(size_t i = 0; i < d_size; i++) {
                T src = *reinterpret_cast<T*>(other.d_data + i * sizeof(T));
                T* dest = reinterpret_cast<T*>(d_data + i * sizeof(T));

                new (dest) T(src);
            }

            return *this;
        }

        // move constructor
        Vector(Vector<T>&& other) noexcept :
            d_data{std::exchange(other.d_data, nullptr)},
            d_size{std::exchange(other.d_size, 0)},
            d_capacity{std::exchange(other.d_capacity, 0)}
        {
        }

        // move assignment
        Vector<T>& operator=(Vector<T>&& other) noexcept {
            if(this == &other) return *this;

            // delete original data
            for(size_t i = 0; i < d_size; i++) {
                get_raw_elem_mutable(i).~T();
            }

            // VR: delete doesn't need parentheses
            // VR: should also be `::operator delete`
            deallocate(d_data);

            d_data = std::exchange(other.d_data, nullptr);
            d_size = std::exchange(other.d_size, 0);
            d_capacity = std::exchange(other.d_capacity, 0);

            return *this;
        }

        Vector(std::initializer_list<T> list) : 
            d_size(list.size()),
            d_capacity(d_size),
            d_data(allocate(list.size()))   
        {
            for(size_t i = 0; const T& elem : list) {
                new (get_raw_elem_mutable(i)) T(elem);

                i++;
            }
        }

        ~Vector() {
            for(size_t i = 0; i < d_size; i++) {
                get_raw_elem_mutable(i)->~T();
            }

            deallocate(d_data);
        }

        void resize(size_t size) {
            std::byte* newByteBuffer = allocate(size);

            for(size_t i = 0; i < ; i++) {
                T* src = nullptr;
                T* dest = reinterpret_cast<T*>(newByteBuffer + i * sizeof(T));

                if(i < d_size) {
                    src = get_raw_elem_mutable(i);
                    get_raw_elem_mutable(i)->~T();
                }
                else {
                    src = new T();
                }

                new (dest) T(std::move_if_noexcept(*src));
            }

            deallocate(d_data);

            d_capacity = std::max(size, d_capacity);
            d_size = size;
            d_data = newBuffer;
        }

        template <typename U>
        void emplace_back(U&&...) {
            if(d_size == d_capacity) {
                if(d_capacity == 0) { this->reserve(1); }
                else {
                    this->reserve(d_size * 1.3);
                }
            }

            T* obj = new T(U...);

            new (get)
        }

        template <typename U>
        void push_back(U&&) {
            if(d_size == d_capacity) {
                if(d_capacity == 0) { this->reserve(1); }
                else {
                    this->reserve(d_size * 1.3);
                }
            }

            new (get_raw_elem_mutable(d_size)) T(std::forward(U));
            d_size++;
        }

        T* data() {
            return reinterpret_cast<T*>(d_data);
        }

        const T* data() const {
            return reinterpret_cast<const T*>(d_data);
        }

        void reserve(size_t newCapacity) {
            if(newCapacity <= d_capacity) return;

            std::byte* newByteBuffer = allocate(newCapacity);

            // copy over old data to new buffer
            for(size_t i = 0; i < d_size; i++) {
                T* src = reinterpret_cast<T*>(d_data + i * sizeof(T));
                T* dest = reinterpret_cast<T*>(newByteBuffer + i * sizeof(T));

                new (dest) T(std::move_if_noexcept(*src));

                src->~T();
            }


            d_capacity = newCapacity; // VR: move this after the allocation for exception safety

            // delete old buffer and reassign
            deallocate(d_data);
            d_data = newByteBuffer;
        }

        T* begin() {
            return reinterpret_cast<T*>(d_data);
        }

        T* end() {
            return reinterpret_cast<T*>(d_data + d_size * sizeof(T));
        }

        const T* begin() const {
            return reinterpret_cast<const T*>(d_data);
        }

        const T* end() const {
            return reinterpret_cast<const T*>(d_data + d_size + sizeof(T));
        }

};

using namespace std;

struct Foo
{
    Foo(std::string&& tempString, int& intRef)
    {}
};

struct Bar
{
    explicit Bar(int) { }
};

int main() {
    Vector<int> v = { 1, 2, 3, 4 };

    // v.push_back(1);
    // v.push_back(2);

    for(int x : v) {
        std::cout << x << std::endl;
    }

    Vector<Foo> vf;


    // vf.push_back(Foo{std::string{"abc"}, i});

    int i;
    vf.emplace_back(std::string{"abc"}, i);
        // it should DIRECTLY invoke `Foo` constructor in the
        // free slot of the vector with
        // `Foo(std::string{"abc"}, i)`

    Vector<Bar> vb;
    vb.push_back(1); // this shouldn't compile
    vb.emplace_back(1); // this should compile
}

// VR: For alignment:
// - use aligned new/delete
// - the value of sizeof(T) is always an integer multiple of alignof(T)

struct alignas(128) bigint
{
    int i;
    // ...124 padding bytes...
};

static_assert(sizeof(bigint) == 128);
static_assert(alignof(bigint) == 128);
