# Tests de la logique (CoreTests)

Ce paquet teste, hors iPad, le code « pur » de l'app : géométrie des pages, mise en forme du texte,
regroupement des lignes OCR en bulles, analyse grammaticale par règles.

Le code testé vit dans `AssistantComics.swiftpm/Core` (c'est lui qu'utilise l'app). Il est copié ici
avant les tests :

```sh
cd CoreTests
cp ../AssistantComics.swiftpm/Core/*.swift Sources/ComicsCore/
swift test
```

Sur GitHub, le workflow `.github/workflows/verification.yml` fait la même chose sur un Mac, puis
compile l'app complète pour le simulateur iPad.
