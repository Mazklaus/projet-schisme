# Étude — Hérésie d'Horus : forme de jeu (Game Design)

*Game Designer · 18 novembre 2026 · phase d'étude, projet privé, rien de Le Dernier Pli n'est repris*

**Recommandation en une phrase :** une aventure narrative cinématique à chapitres, construite comme un récit à choix (type Telltale) avec des séquences jouables courtes et scénarisées (type God of War en version légère). Les points de vue changent à chaque chapitre, et l'agentivité du joueur porte sur le *comment* et le *qui*, jamais sur le *quoi* du canon.

---

## 1. Les formes possibles

| Forme | Ce que fait le joueur | Part de ciné | Exemples | Adéquation avec l'Hérésie |
| --- | --- | --- | --- | --- |
| Récit à choix | Dialogues à choix minutés, QTE, petites zones d'exploration | 60–70 % | The Walking Dead, The Wolf Among Us (Telltale), Life is Strange | **Forte.** Épisodique par nature, cinématique, centrée sur les relations et les choix moraux locaux. Défaut : action pauvre pour un univers de guerre. |
| Film interactif | Actions contextuelles fines, scènes à embranchements lourds, personnages qui peuvent mourir | 70–80 % | Heavy Rain, Detroit: Become Human, Until Dawn | **Moyenne.** Le très bon modèle des points de vue multiples (Detroit), mais il promet des embranchements massifs que le canon interdit. Coût de production très élevé. |
| Aventure cinématique avec séquences jouables | Exploration, combat, traversées, cinématiques intégrées sans coupure | 30–40 % | The Last of Us, God of War (2018), Hellblade | **Forte sur le ressenti** (on *est* un Astartes), **faible sur les choix** (histoire linéaire). Le coût du combat est énorme. |
| Roman visuel | Lecture, choix de dialogue, illustrations | 90 % (texte et images fixes) | 13 Sentinels (partie récit), Disco Elysium (proche par l'écrit), Pentiment | **Moyenne.** Faisable, riche en points de vue, mais peu « cinématique » au sens où l'utilisateur l'entend. |
| Ciné + phases tactiques | Cinématiques, puis batailles au tour par tour ou en temps réel, puis cinématiques | 40–50 % | Mechanicus (Warhammer), Banner Saga, Fire Emblem | **Bonne pour l'échelle** (Isstvan, le Siège), **mauvaise pour l'intime** (les trahisons se jouent entre personnes). Deux jeux en un, donc coûteux. |

---

## 2. La tension centrale : un canon connu

Le joueur sait déjà qu'Horus trahit, qu'Isstvan III et Isstvan V ont lieu, et que le Siège de Terra se termine par la mort d'Horus et l'Empereur sur le Trône d'Or. **On n'en fait pas un défaut : c'est de l'ironie tragique.** Le joueur sait, les personnages non. Chaque choix est alors fait en connaissant le prix.

**Ce qu'on ne touche jamais :** les grands événements, le camp de chaque Légion et de chaque Primarque, la mort ou la survie des personnages majeurs du canon, l'issue des batailles.

**Ce qu'on peut laisser au joueur :**

| Levier | Exemple | Risque pour le canon |
| --- | --- | --- |
| Le point de vue | Vivre Isstvan III du côté d'un Astartes loyaliste des Sons of Horus, puis du côté d'un remembrancer | Aucun |
| Le ton et la manière | Mener l'évacuation avec dureté ou avec compassion ; mentir ou dire la vérité à un frère | Aucun |
| Les relations | Confiance ou méfiance entre deux personnages ; à qui l'on se confie | Faible, s'il s'agit de personnages originaux |
| La survie des personnages secondaires *originaux* | Un sergent, une chroniqueuse, un pilote, inventés pour le jeu, qui vivent ou meurent selon les choix | Aucun, c'est le meilleur levier |
| Les actions héroïques locales | Sauver une escouade, tenir une porte dix minutes de plus, transmettre un avertissement | Faible, l'issue de la bataille ne change pas |
| Ce que le personnage sait et comprend | Découvrir une vérité ou la refuser, garder un secret | Aucun |
| Les « échos » entre épisodes | Un choix de l'épisode 2 change une scène de l'épisode 6 | Aucun si la scène reste dans le canon |

**Règle de design proposée :** *le canon est le décor fixe, les personnages originaux sont la pièce que le joueur joue.* Les personnages canoniques secondaires dont le sort est inconnu peuvent être touchés au cas par cas, avec l'accord de l'utilisateur. Le Narrative Designer gère la frontière.

---

## 3. Entre deux cinématiques

| Activité | Rôle | Intensité recommandée |
| --- | --- | --- |
| Dialogue à choix | Cœur du jeu : relations, morale, informations | **Haute**, présent dans chaque chapitre |
| Exploration légère | Respirer, découvrir le lore (vaisseau, camp, ruche), parler aux personnages secondaires | **Moyenne** : petites zones de 5 à 10 minutes, pas de monde ouvert |
| Combat | Faire sentir la puissance et l'horreur de la guerre | **Basse à moyenne** : séquences scénarisées et courtes (QTE enrichis, couverture et tir simple, duel chorégraphié), jamais un système de combat profond |
| Moments de décision sous pression | Choisir vite qui sauver, quoi sacrifier | **Haute** : ce sont les sommets d'un chapitre |
| Lecture et enquête | Archives, vox interceptés, journaux de remembrancers | **Basse**, en option, pour les fans du lore |

Pour une petite équipe, chaque minute de combat coûte beaucoup plus qu'une minute de dialogue. Le combat doit rester un ponctuant et non un pilier.

---

## 4. Structure type

La durée totale du jeu n'a pas de limite : les durées ci-dessous sont des repères de rythme pour le joueur (une soirée par épisode, une session par chapitre), pas des contraintes de volume.

**Épisode** (un arc du canon, par exemple « Isstvan III ») : 2 à 3 heures, 4 ou 5 chapitres, avec un ou deux points de vue principaux. Il s'ouvre sur un récapitulatif « Précédemment » qui reprend les choix passés, et se termine sur un écran de choix, avec le pourcentage des autres joueurs si l'on veut un aspect social (option).

**Chapitre** : 30 à 40 minutes.

| Temps | Contenu | Part de ciné |
| --- | --- | --- |
| 0–5 min | Cinématique d'ouverture : situation, enjeu du chapitre | 100 % |
| 5–15 min | Exploration et dialogues : on prépare, on choisit ses alliés | 30 % |
| 15–25 min | Crise : séquence jouable (combat scénarisé, évasion, infiltration) | 40 % |
| 25–35 min | Décision majeure, puis cinématique de bascule (souvent un moment du canon) | 70 % |
| 35–40 min | Retombée : courte scène intime, puis l'accroche du chapitre suivant | 80 % |

Sur l'ensemble : **environ 50 à 60 % de cinématiques et de scènes dirigées**, contre 40 à 50 % de jeu libre.

---

## 5. Recommandation et décisions pour l'utilisateur

**Forme recommandée :** un récit à choix avec des séquences jouables légères, et des points de vue tournants.
- C'est le seul format qui tient à la fois l'épisodique illimité, la place centrale des cinématiques et un canon fixe.
- Les points de vue tournants (Astartes loyaliste, Astartes traître, mortel, Primarque en scène dirigée seulement) donnent la richesse de Detroit sans ses embranchements impossibles.
- Le combat léger reste à la portée d'une petite équipe et peut monter en intensité plus tard si un épisode le justifie (le Siège).

**Décisions à laisser à l'utilisateur :**
1. **Le niveau d'action.** Récit à choix pur (moins cher, plus narratif), ou séquences jouables plus musclées (plus de ressenti, plus de coût) ?
2. **Les points de vue.** Uniquement des personnages originaux, ou aussi des personnages canoniques jouables (Garviel Loken, par exemple) ? Et peut-on jouer un Primarque ?
3. **La liberté sur le canon secondaire.** Les personnages canoniques mineurs au sort inconnu peuvent-ils mourir selon les choix ?
4. **Les fins alternatives.** Faut-il des chapitres « et si… » hors canon, en bonus clairement séparés, ou jamais ?
5. **Le format visuel des cinématiques.** 3D temps réel, 2D animée ou motion comic. C'est à trancher avec le Directeur artistique et le Lead Programmer, car c'est le premier facteur de coût.

*Coordination : le point de vue est à caler avec le Narrative Designer (etude-heresie/narration.md, pas encore écrit au moment de cette version).*
