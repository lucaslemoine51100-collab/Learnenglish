# Learnenglish — Assistant Comics (iPad Pro)

Assistant pédagogique pour lire des comics en anglais sur iPad. Il détecte les bulles, traduit en français, explique la grammaire et garde un historique de progression.

## Version web (utilisable tout de suite sur l'iPad)

- Page : https://claude.ai/artifact/Qyko2mrxB3pBNY2S3oVuqF (privée, réservée au propriétaire)
- Source : [`web/assistant-comics.html`](web/assistant-comics.html)
- Fonctionne dans Safari ou l'app Claude. Elle ouvre un PDF et l'affiche sur l'iPad. Quand vous appuyez sur « Analyser », Claude lit la page, numérote les bulles et les traduit. La grammaire est expliquée à la demande, et l'historique est enregistré avec votre compte.
- Différence avec l'app : l'image de la page analysée est envoyée à Claude, uniquement sur demande.

## App Swift Playgrounds : comics PDF (v0.1)

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
