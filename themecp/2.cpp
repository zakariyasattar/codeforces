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

        vector<int> cap_limits(k);
        for(int& v : cap_limits) cin >> v;

        vector<int> courses(n);
        for(int& v : courses) cin >> v;

        // I think -1 is never gonna happen
        // we push every course into its level, then we iterate from k to 1 and move all elems to k + 1

        vector<vector<int>> buckets(k);
        for(int i = 1; int c : courses) {
            if(c > k) { i++; continue; }
            buckets[c - 1].push_back(i);
            i++;
        }

        vector<int> res;

        // or we can iter through buckets
        for(int i = buckets.size() - 1; i >= 0; i--) {
            while(buckets[i].size() > 0) {
                for(int j = 0; j <= k - 1 - i; j++) {
                    res.push_back(buckets[i].back());
                }
                buckets[i].pop_back();
            }
        }

        cout << res.size() << endl;

        for(int r : res) cout << r << " ";
        cout << endl;

    }

    return 0;
}