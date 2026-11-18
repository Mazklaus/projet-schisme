# Étude technique : jeu narratif à épisodes (projet-schisme)

*Lead Programmer, 18/11/2026. Phase d'étude : pas de code. Dépôt de travail : `projet-schisme` (privé).*

## En bref

- **Moteur recommandé : Unreal Engine 5.6 ou plus.** C'est le seul moteur où l'on trouve, intégrés et gratuits jusqu'à 1 M$ de revenus, les outils dont le projet a besoin : Sequencer, MetaHuman, Control Rig, animation faciale tirée de l'audio, Lumen et Nanite.
- **La vraie limite, ce sont les assets, pas le moteur.** Sans artistes 3D humains, une équipe d'agents peut produire de bons décors et des accessoires « industriels » : kitbash, Blender en script, marketplace, génération IA pour les seconds plans. En revanche, elle **ne peut pas produire seule** de personnages héros au niveau AAA, comme des Space Marines en armure et en gros plan. Réaliste : du **AA stylisé** proche d'une cinématique de jeu indépendant ambitieux, à condition d'acheter des bases (packs marketplace) et d'accepter quelques heures d'un artiste en freelance pour les héros.
- **Nos conteneurs cloud n'ont pas de GPU.** Unreal ne peut ni rendre ni être vérifié visuellement depuis nos threads. Il faudra le PC de l'utilisateur, avec une carte RTX, pour l'éditeur, le rendu, les tests et les captures (Remote Control). C'est le risque n°1 pour l'organisation.
- **Licence de l'univers** : Games Workshop défend activement son IP, y compris contre des animations de fans. Le projet doit rester strictement privé : dépôt privé, aucune diffusion de build, de vidéo ni de capture publique.

---

## 1. Choix du moteur

| Critère | **Unreal Engine 5.6+** | Unity 6 (HDRP) | Godot 4 |
|---|---|---|---|
| Cinématiques temps réel | **Sequencer** : montage non linéaire, caméras ciné, Take Recorder, Movie Render Queue | Timeline + Cinemachine : solide, mais moins complet pour le montage ciné | AnimationPlayer : correct pour du 2D ou de la 3D simple, pas d'outil de montage ciné |
| Rendu haut de gamme | **Lumen** (GI dynamique), **Nanite** (géométrie massive), MegaLights, chevelure Groom | HDRP : très bon, mais **plus aucune nouvelle fonctionnalité prévue** (maintenance seulement, stratégie 2026) | Forward+/SDFGI : nettement en dessous pour du photoréaliste |
| Personnages et visages | **MetaHuman** intégré, gratuit, rig facial complet | Pas d'équivalent natif. MetaHuman est désormais exportable vers d'autres moteurs, mais sans les outils d'animation | Idem, MetaHuman importable sans les outils |
| Lip-sync | **MetaHuman Animator** : animation faciale **depuis l'audio** (5.6+), ou depuis une vidéo de téléphone ou de webcam | Plugins tiers payants | Plugins tiers |
| Rig et animation | **Control Rig**, IK Retargeter, Motion Matching, ML Deformer | Animation Rigging, correct | Basique |
| Coût | Gratuit, **5 % au-delà de 1 M$** de revenus par jeu ; pas de licence par poste pour un jeu | Gratuit sous un seuil, puis abonnement Pro par poste | Gratuit (MIT) |
| Travail par des agents | C++ et Python éditeur en texte, mais **Blueprints, niveaux et séquences en binaire** (.uasset) : il faut l'éditeur et un GPU | C# en texte, scènes en YAML (lisibles) | **Tout en texte**, headless : notre point fort actuel |
| Poids et machine | Éditeur d'environ 100 Go, carte RTX, 32 à 64 Go de RAM | Moyen | Léger |

**Recommandation : Unreal Engine 5.6+**, pour la qualité ciné demandée. Unity HDRP est un pari risqué, puisque le pipeline n'évolue plus. Godot reste excellent pour notre façon de travailler, mais ne tient pas le niveau visuel visé.

**Le prix à payer avec Unreal**, à accepter consciemment :
- Une bonne partie du contenu (séquences, Blueprints, niveaux) est en binaire et s'édite dans l'éditeur. Nous écririons donc **le maximum en C++ et en Python d'éditeur** (création de séquences, placement, import en lot), et réserverions l'éditeur au réglage visuel.
- Il faut le PC de l'utilisateur, ou une machine cloud avec GPU, pour ouvrir l'éditeur, rendre et tester.
- Il faut Git LFS pour les assets binaires, ou Perforce. Le dépôt GitHub privé suffit pour commencer, avec LFS, mais les quotas LFS sont payants au-delà du gratuit.

## 2. Pipeline des cinématiques et des assets

```
Script / storyboard (GD, Narrative)
  → Previz dans Unreal : blocage caméras + mannequins (Sequencer)
  → Assets : Blender (modèles, kitbash) + marketplace Fab + MetaHuman (visages humains)
  → Rig : MetaHuman (humains) ; Control Rig / Auto-Rig Pro (créatures, armures)
  → Animation corps : bibliothèques (Fab, Mixamo pour le prototype) + capture vidéo IA + reprise Control Rig
  → Visage / lip-sync : MetaHuman Animator depuis l'audio (ou vidéo webcam/téléphone)
  → Voix : comédiens (cachets) ou synthèse vocale sous licence commerciale
  → Montage et rendu : Sequencer, temps réel in-engine (cinématiques jouées dans le jeu)
```

- **Modélisation** : Blender, avec des scripts Python pour le kitbash, la génération procédurale (Geometry Nodes) et l'export en lot. Fab (la marketplace d'Epic) fournit des bases sous licence commerciale.
- **Capture de mouvement sans studio** : la capture par vidéo IA (Move.ai, Rokoko Vision, Cascadeur pour reprendre les poses) donne une base exploitable à partir d'une vidéo filmée au téléphone, mais il faut **filmer une personne qui joue la scène**, donc l'utilisateur ou un proche. Sans cela, il reste les bibliothèques d'animations, qui suffisent pour la marche, les gestes et les combats génériques, et l'animation clé par clé dans Control Rig, lente.
- **Visages** : MetaHuman Animator produit l'animation faciale (lèvres, et en option tête et clignements) **directement depuis un fichier audio** depuis la 5.6, sans capture. C'est l'outil qui rend un jeu narratif dialogué faisable pour nous.
- **Temps réel ou précalculé** : **temps réel**, joué dans le moteur. Un jeu à épisodes avec des choix ne peut pas embarquer des dizaines de Go de vidéo. La Movie Render Queue peut, si besoin, précalculer quelques plans en vidéo, par exemple pour une bande-annonce interne.

## 3. Ce que notre équipe peut réellement produire (la question clé)

Pour être franc : **les agents savent écrire du code, des scripts Blender et des outils, mais pas sculpter un personnage héros**.

| Type d'asset | Méthode réaliste pour nous | Qualité atteignable | Coût, licence |
|---|---|---|---|
| Décors (couloirs de vaisseaux, ruines, architecture gothique) | Kitbash en Blender piloté par script + packs Fab + Nanite | **Bonne à très bonne** : le style gothique répétitif se prête bien au procédural | Packs à 20–300 $ chacun, licence Fab standard, usage commercial OK |
| Accessoires (armes, caisses, consoles) | Packs Fab + génération IA (Meshy, Tripo, Hunyuan3D) pour les seconds plans | Bonne en arrière-plan, médiocre en gros plan sans reprise | IA : forfaits payants pour l'usage commercial ; Hunyuan3D auto-hébergeable (licence à lire) |
| Humains non augmentés (officiers, serviteurs) | **MetaHuman** + vêtements des packs | **Très bonne** : c'est le point fort | Gratuit sous 1 M$ |
| Héros en armure (Astartes, primarques) | Base achetée ou commandée, puis variations par script (couleurs de Légion, insignes, casques) | **Correcte en plan moyen**. En gros plan, il faut un artiste humain (freelance) pour 3 à 6 modèles de base | Freelance : quelques centaines à quelques milliers d'€ par modèle héros. Packs sci-fi en armure : 50–300 $ |
| Créatures, démons | Packs + IA pour les concepts | Moyenne | Variable |
| Animation | Bibliothèques + capture vidéo IA + reprise | Bonne pour les gestes et dialogues, moyenne pour les combats chorégraphiés | Move.ai / Rokoko : abonnements mensuels |
| Visages parlants | MetaHuman Animator depuis l'audio | Bonne | Gratuit |

**Génération 3D par IA, état fin 2026** : ces outils amènent vite à « 80 % ». La topologie est souvent un amas de triangles qui se déforme mal une fois riggé, les UV sont à refaire, et les détails mécaniques fins restent faibles. Ils conviennent au **prototype, à la previz et aux seconds plans**, pas aux héros animés. Sur le plan juridique, une création purement IA n'est pas protégeable aux États-Unis, et les versions gratuites des outils sont souvent sous CC BY ou en usage non commercial.

**Conséquence de cadrage** : un épisode réaliste, c'est **peu de personnages héros, réutilisés**, beaucoup de dialogues de visages (MetaHuman), des décors procéduraux, et des scènes d'action filmées « au cadrage » (fumée, contre-jour, plans serrés) plutôt qu'en grande bataille chorégraphiée.

## 4. Format épisodique

- **Un seul jeu, avec des épisodes en DLC** : chaque épisode est un **paquet de contenu séparé**. Dans Unreal, c'est le « chunking » et les *Primary Asset Labels* : un .pak par épisode, ajouté par mise à jour ou DLC Steam.
- **Code commun et contenu par épisode** : le moteur, les systèmes (dialogues, choix, sauvegarde) et les personnages récurrents sont dans le socle. Chaque épisode apporte ses niveaux, ses séquences et ses voix.
- **Sauvegardes** : un état de choix **versionné** (SaveGame Unreal, ou JSON), qui porte les choix d'un épisode à l'autre, avec une migration de version à chaque épisode. Le joueur doit pouvoir importer « l'état de fin de l'épisode N » pour commencer N+1.
- **Données narratives en texte** : dialogues et choix dans un format texte (Ink, Yarn, ou un format maison), pour que les agents (Narrative, Gameplay) puissent les écrire et les tester sans l'éditeur.

## 5. Risques et ampleur

| Risque | Gravité | Parade |
|---|---|---|
| **IP Games Workshop** : retrait ou mise en demeure si quoi que ce soit fuit | Élevée | Dépôt privé, aucune diffusion publique (builds, vidéos, captures), nom de travail neutre |
| **Pas de GPU dans nos conteneurs** : nous ne pouvons ni rendre ni vérifier les cinématiques | Élevée | PC de l'utilisateur avec une RTX, via Remote Control, ou machine cloud avec GPU (coût horaire) |
| Assets héros hors de portée des agents | Élevée | Achats Fab, freelance pour les héros, cadrage qui limite les gros plans d'armure |
| Fichiers binaires Unreal difficiles à relire et à fusionner | Moyenne | Maximum en C++ et Python d'éditeur, verrous LFS sur les .uasset, une personne par niveau |
| Poids du dépôt (des dizaines de Go) | Moyenne | Git LFS (quotas payants) ou Perforce à terme |
| Courbe d'apprentissage d'Unreal pour l'équipe | Moyenne | Prototype « tranche verticale » d'une scène de 2 minutes avant tout engagement |

**Ampleur** : un épisode d'environ 1 h 30 avec des cinématiques temps réel de bon niveau, c'est l'équivalent de **plusieurs mois de travail d'équipe**, même avec des agents. Le goulot, c'est l'assemblage visuel dans l'éditeur, plus la capture et la reprise d'animation, pas l'écriture ni le code.

**Proposition d'étape suivante** : une **tranche verticale** d'une seule scène de 2 à 3 minutes (deux personnages qui dialoguent, un MetaHuman et un Astartes acheté, un décor de vaisseau procédural, une caméra Sequencer, lip-sync depuis l'audio), réalisée sur le PC de l'utilisateur. Elle validera, ou invalidera, toute la chaîne avant d'écrire un épisode.

---

## Sources consultées

- Tarifs Unreal Engine (5 % au-delà de 1 M$, seats) : https://www.unrealengine.com/en-US/blog/we-are-updating-unreal-engine-twinmotion-and-realitycapture-pricing-in-late-april
- Licence MetaHuman (gratuit sous 1 M$, utilisable dans d'autres moteurs) : https://www.metahuman.com/license et https://www.cgchannel.com/2025/06/you-can-now-sell-metahumans-or-use-them-in-unity-or-godot/
- Animation faciale depuis l'audio (UE 5.6+) : https://dev.epicgames.com/documentation/en-us/metahuman/audio-driven-animation et https://metahuman.com/news/metahuman-leaves-early-access-with-a-feature-packed-new-release
- Stratégie Unity 2026, HDRP en maintenance : https://unity.com/topics/render-pipelines-strategy-for-2026 et https://80.lv/articles/unity-unveils-2026-render-pipelines-strategy/
- Génération 3D par IA (qualité, topologie, licences) : https://kompozy.io/guides/ai-generated-3d-models et https://inker.si/blog/best-ai-3d-model-generators-2026
- Capture de mouvement par vidéo : https://www.rokoko.com/insights/introducing-rokoko-vision-3-0 et https://www.strayspark.studio/blog/ai-mocap-indie-developers-2026-comparison
- Rendu Unreal sans écran (GPU requis) : https://forums.unrealengine.com/t/rendering-in-headless-mode-possible/475619
- IP Games Workshop et œuvres de fans : https://pcgamer.com/uk/games-workshop-is-trying-to-shut-down-fan-animations et https://spikeybits.com/2021/07/lookout-youtube-gw-just-updated-their-ip-guidelines.html
