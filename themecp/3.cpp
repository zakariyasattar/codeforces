#include <bits/stdc++.h>

using namespace std;
using ll = long long;

#define debug(x) cerr << #x << " = " << x << endl;
#define vdebug(a) cerr << #a << " = "; for(auto x: a) cerr << x << ' '; cerr << endl;

int main() {
	int T;
	cin >> T;

	const ll MOD = 998244353;

	// focus on groups of 3 at a time, and see how many ways we can make it valid
	// if we come across a group that we cant make valid, then the whole string becomes 0

	while(T--) {
		int n;
		cin >> n;

		string s;
		cin >> s;

		ll res {};

		for(int i = 0; i < n - 2; i++) {
			char a {s[i]}, b {s[i + 1]}, c {s[i + 2]};
			if(a != '?' && b != '?' && c != '?') continue;

			cerr << a << " " << b << " " << c << endl;
		}

		cout << res << endl;
	}

	return 0;
}