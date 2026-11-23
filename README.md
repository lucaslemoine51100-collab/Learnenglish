# Learnenglish — Assistant Comics (iPad Pro)

Assistant pédagogique pour lire des comics en anglais sur iPad. Il détecte les bulles, traduit en français, explique la grammaire et garde un historique de progression.

## Version actuelle : comics PDF (v0.1)

App **Swift Playgrounds** : elle se lance gratuitement sur l'iPad, sans Mac.

- Code : [`AssistantComics.swiftpm`](AssistantComics.swiftpm)
- Fonctionnement, installation et limites : [docs/version-pdf.md](docs/version-pdf.md)
- Traitement 100 % local : OCR Vision, traduction Translation, grammaire Apple Intelligence ou règles.

## Étude de faisabilité : capture de Marvel Unlimited / Marvel Comics

- Rapport : [docs/etude-faisabilite-ipad.md](docs/etude-faisabilite-ipad.md)
- Verdict : **GO conditionnel** pour les tests sans coût, **aucune dépense** avant validation sur l'appareil.
- Marvel Unlimited s'arrête en décembre 2026 au profit de « Marvel Comics powered by WEBTOON ».

## Vérification automatique

Le workflow [Vérification sur Mac](.github/workflows/verification.yml) lance les tests de la logique (`CoreTests`) et compile l'app pour le simulateur iPad à chaque modification.
