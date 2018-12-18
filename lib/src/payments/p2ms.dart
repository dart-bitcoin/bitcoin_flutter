
import '../utils/constants/op.dart';

class P2MS {

  bool stacksEqual (a, b) {
    if (a.length != b.length) return false;
    for(int i=1;i<=a.length;i++) {
      if (a[i]!=b[i]) {
        return false;
      }
    }
    return true;
  }
}