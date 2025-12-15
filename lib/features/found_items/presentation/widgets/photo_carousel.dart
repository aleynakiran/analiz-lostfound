import 'package:flutter/material.dart';
import 'package:campus_lost_found/core/domain/item_photo.dart';
import 'package:campus_lost_found/core/constants/categories.dart';

class PhotoCarousel extends StatelessWidget {
  final List<ItemPhoto> photos;
  final String category;

  const PhotoCarousel({
    super.key,
    required this.photos,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return Container(
        height: 300,
        width: double.infinity,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ItemCategories.icons[category] ?? '📦',
                style: const TextStyle(fontSize: 80),
              ),
              const SizedBox(height: 16),
              Text(
                'No photos available',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 300,
      child: PageView.builder(
        itemCount: photos.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: photos[index].assetPath.startsWith('http')
                ? Image.network(
                    photos[index].assetPath,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded /
                                  (progress.expectedTotalBytes ?? 1)
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, _, __) {
                      return Center(
                        child: Text(
                          ItemCategories.icons[category] ?? '📦',
                          style: const TextStyle(fontSize: 80),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Text(
                      ItemCategories.icons[category] ?? '📦',
                      style: const TextStyle(fontSize: 80),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

