# Assistant Comics — version PDF (v0.1)

Première version de l'assistant. Elle travaille sur **des comics au format PDF ouverts dans l'app**, au lieu de capturer l'écran de Marvel Unlimited ou Marvel Comics.

## Pourquoi commencer par le PDF

L'étude de faisabilité ([etude-faisabilite-ipad.md](etude-faisabilite-ipad.md)) montre que la capture d'une autre application dépend de quatre choses : une extension de diffusion ReplayKit, Xcode, l'abonnement développeur payant, et surtout le bon vouloir de l'éditeur, qui peut bloquer la capture. Avec un PDF ouvert dans notre propre app, **ces contraintes disparaissent** :

| | Capture de Marvel (cible finale) | Version PDF (celle-ci) |
|---|---|---|
| Accès à l'image de la page | Diffusion d'écran + extension | Rendu direct du PDF |
| Dépend de l'éditeur | Oui (peut bloquer la capture) | Non |
| Outil de développement | Xcode sur Mac (loué) | **Swift Playgrounds sur l'iPad** |
| Coût | 99 USD/an minimum | **0 €** |
| Fenêtre de l'assistant présente dans la capture | Oui (à masquer) | Non (la page est rendue sans l'assistant) |

Le **moteur d'analyse** est réutilisable tel quel pour la version Marvel si elle devient possible : OCR, découpage en bulles, traduction, grammaire, historique.

## Ce que fait l'app

1. **Bibliothèque** : import de PDF depuis l'app Fichiers. Les fichiers sont copiés dans l'app et ne quittent pas l'iPad.
2. **Lecture** page par page, avec un glissement pour tourner. L'app reprend à la dernière page lue.
3. **Assistant flottant** au-dessus de la page :
   - déplaçable (par sa barre de titre) ;
   - redimensionnable (coin inférieur droit) ;
   - réductible en pastille (bouton « – ») ;
   - position et taille mémorisées.
4. **« Analyser »** : la page est convertie en image, puis l'app :
   - reconnaît le texte anglais avec **Vision**, sur l'iPad ;
   - regroupe les lignes en **bulles numérotées** dans l'ordre de lecture ;
   - affiche des **repères numérotés** sur la page, en mémoire seulement : **le fichier PDF n'est jamais modifié**. Le bouton « # » les masque.
5. **Choix d'une bulle** : dans la liste, ou en **touchant la bulle sur la page**.
   - La **traduction française** utilise le framework **Translation**, sur l'iPad.
   - Si l'OCR s'est trompé, on corrige le texte anglais, puis on appuie sur « Retraduire ».
6. **« Expliquer la grammaire »** :
   - avec **Apple Intelligence** (modèle local), si l'iPad le permet ;
   - sinon, avec des **repères automatiques** par règles : temps verbaux, contractions, argot (« gonna »…), modaux, verbes à particule, expressions, types de phrases.
7. **Historique** : chaque réplique traduite est conservée (texte seulement, jamais d'image), avec recherche, suppression et export en texte.

Tout le traitement est local. L'app ne fait aucun appel réseau, sauf le téléchargement éventuel des langues de traduction par iPadOS.

## Installer et lancer sur l'iPad (gratuit)

Prérequis : **Swift Playgrounds** (gratuit sur l'App Store), version 4.7 ou ultérieure de préférence, et iPadOS 18 ou ultérieur.

1. Sur l'iPad, dans Safari, téléchargez le dépôt en ZIP :
   `https://github.com/lucaslemoine51100-collab/Learnenglish/archive/refs/heads/claude/comics-assistant-ipad-feasibility-qojr9w.zip`
2. Dans l'app **Fichiers**, ouvrez « Téléchargements » et touchez le ZIP pour le décompresser.
3. Ouvrez le dossier obtenu, puis touchez **`AssistantComics.swiftpm`**. Il s'ouvre dans Swift Playgrounds. Sinon, ouvrez-le depuis Swift Playgrounds (liste des projets > emplacements, selon la version).
4. Appuyez sur **▶︎ (Exécuter)**. Swift Playgrounds compile l'app et la lance.
5. Dans l'app, touchez **+** pour importer un comic PDF.

> Si Swift Playgrounds affiche une erreur de compilation, copiez son message : il sera corrigé dans le projet.
> Chaque modification du projet est d'abord compilée automatiquement sur un Mac de GitHub (workflow « Vérification sur Mac »).

### Où trouver des comics PDF pour tester

- Vos propres PDF **sans DRM** (achats éditeurs ou plateformes qui proposent le téléchargement).
- Des comics anglais du **domaine public**, par exemple sur Internet Archive (archive.org), souvent disponibles en PDF.

Les numéros lus dans Marvel Unlimited ou Marvel Comics **ne peuvent pas** être exportés en PDF, et l'app ne contourne aucune protection.

## Limites connues de la v0.1

- **Ordre de lecture approché** : de haut en bas, puis de gauche à droite. Les cases du comic ne sont pas encore détectées.
- **Découpage en bulles heuristique** : deux bulles très proches peuvent être fusionnées, et un long récitatif peut être coupé en deux.
- **OCR** : le lettrage stylisé (cris, onomatopées, polices manuscrites) peut produire des erreurs. Le texte est modifiable avant traduction.
- **Formats** : PDF uniquement (CBZ/CBR et images à venir).
- **Grammaire sans Apple Intelligence** : repères simples, signalés comme tels.
- **Pas de lecture double page** : affichage page par page.

## Prochaines étapes possibles

1. Tester sur de vrais PDF et ajuster les réglages du découpage (`BubbleGrouper.Options`).
2. Détection des cases pour un meilleur ordre de lecture.
3. Import CBZ (archives d'images) et d'images isolées.
4. Fiches de révision tirées de l'historique (répétition espacée).
5. Si la Phase 0 de l'étude est concluante : brancher ce même moteur sur la capture d'écran de Marvel Comics.

## Organisation du code

| Dossier | Contenu |
|---|---|
| `AssistantComics.swiftpm/Core` | Logique pure, testée : géométrie des pages, mise en forme du texte, regroupement en bulles, analyse grammaticale par règles |
| `AssistantComics.swiftpm/Services` | Bibliothèque, historique, analyse OCR (PDFKit + Vision), traduction (Translation), grammaire (Foundation Models) |
| `AssistantComics.swiftpm/Reader` | Lecteur PDF, fenêtre flottante, panneau de l'assistant |
| `AssistantComics.swiftpm/Views` | Bibliothèque, historique |
| `CoreTests` | Tests unitaires de `Core` (exécutés sur Mac par GitHub Actions) |
