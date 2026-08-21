import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Image réseau avec cache disque + placeholder shimmer.
///
/// Remplace tous les `Image.network` de l'app : sans cache, chaque ouverture
/// d'écran re-télécharge les photos de profil/logos (data + latence + flash
/// blanc). `cached_network_image` garde les fichiers sur disque et les sert
/// instantanément aux affichages suivants.
class AppCachedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? errorWidget;

  const AppCachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: Container(width: width, height: height, color: Colors.white),
      ),
      errorWidget: (_, __, ___) =>
          errorWidget ??
          Container(
            width: width,
            height: height,
            color: Colors.grey.shade100,
            alignment: Alignment.center,
            child: Icon(Icons.image_not_supported_outlined,
                color: Colors.grey.shade400),
          ),
    );
  }
}
