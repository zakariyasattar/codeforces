#include <bits/stdc++.h>

using namespace std;
using ll = long long;

#define debug(x) cerr << #x << " = " << x << endl;
#define vdebug(a) cerr << #a << " = "; for(auto x: a) cerr << x << ' '; cerr << endl;

int main() {
    int T;
    cin >> T;

    while(T--) {
        int n, k;
        cin >> n >> k;

        string s;
        cin >> s;

        int total {};

        for(int i = 0; i < s.size(); i += k) {
            bool can_avoid {};

            for(int j = i; j < i + k; j++) {
                if(s[j] != '1') {
                    can_avoid = true;
                }
            }

            // if we cant avoid, then we must build on his land
            total += !can_avoid;
        }

        cout << total << endl;
    }

    return 0;
}