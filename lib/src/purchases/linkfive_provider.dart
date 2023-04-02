import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linkfive_purchases_provider/provider/linkfive_provider.dart';

final linkFiveProvider = ChangeNotifierProvider((ref) => LinkFiveProvider(
    "4ab7a805805e3ab138b02043d3d8428ded9d0d37217fa4ad6f0cb782a2a124e1"));
