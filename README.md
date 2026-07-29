# PowerApps
Test Pipelines for Power Apps

## Workflow de développement maker

Ce dépôt doit être traité en code first. La source de vérité est Git, pas l'environnement Power Apps d'un développeur.

### Principes

- Chaque développeur travaille dans son propre environnement de développement jetable.
- Chaque branche de feature correspond à un environnement préparé depuis une base Git connue.
- On ne capture jamais des changements depuis un environnement qui n'est plus aligné sur la base Git attendue.
- Si `main` avance sur une solution pendant qu'une feature est en cours, l'environnement doit être recréé avant une nouvelle capture.

### Flux recommandé

1. Lancer `prepare-dev-environment` pour créer la branche de travail et réinitialiser l'environnement du développeur à partir de `main`.
2. Ouvrir l'environnement préparé et faire les changements maker uniquement dans la solution visée.
3. Lancer `capture-dev-changes` pour exporter la solution et pousser les fichiers unpacked sur la branche.
4. Ouvrir une Pull Request et merger dans `main`.
5. Laisser `single-run-promotion` promouvoir les changements vers les environnements supérieurs.

### Quand il faut recréer l'environnement

Il faut relancer `prepare-dev-environment` dans les cas suivants:

- Un autre développeur a mergé des changements dans `main` sur la même solution.
- `capture-dev-changes` échoue en indiquant que `main` a changé depuis la divergence de la branche.
- La branche de travail a été rebasée sur `main`.
- Le développeur a un doute sur l'état réel de son environnement par rapport au dépôt.

### Procédure de récupération quand la capture est bloquée

Si `capture-dev-changes` bloque parce que `main` a avancé sur la même solution, ne pas lancer immédiatement `prepare-dev-environment` si l'environnement contient encore du travail maker non capturé.

Procédure recommandée:

1. Lancer `backup-dev-changes` pour exporter la solution courante en artefact de secours.
2. Rebaser la branche locale sur `main`.
3. Lancer `prepare-dev-environment` pour recréer l'environnement sur la nouvelle base Git.
4. Ouvrir l'artefact de backup comme référence et rejouer ou revalider les changements nécessaires dans l'environnement rafraîchi.
5. Lancer `capture-dev-changes` une fois l'environnement de nouveau aligné.

Le backup n'est pas une fusion automatique. C'est un filet de sécurité pour éviter de perdre le travail maker avant un reset.

### Pourquoi ce garde-fou existe

L'export d'une solution Power Apps reflète l'état complet de la solution dans l'environnement source. Si deux développeurs travaillent chacun dans un environnement différent sur la même solution, le second export peut retirer des composants qui existent déjà dans `main` mais pas dans son environnement local. Le workflow bloque donc cette capture au lieu de laisser passer un écrasement silencieux.

### Règles d'équipe

- Éviter autant que possible que deux développeurs modifient en parallèle la même app, les mêmes formulaires, ou le même `AppModule` dans une même solution.
- Découper les solutions par domaine fonctionnel quand c'est possible pour réduire les collisions.
- Considérer les environnements de développement comme des copies de travail temporaires, jamais comme une source de vérité durable.
- En cas de conflit fonctionnel sur une même surface maker, la bonne résolution est de resynchroniser l'environnement puis de rejouer ou réappliquer le changement, pas d'essayer de fusionner deux exports divergents.

### Workflows concernés

- `prepare-dev-environment` prépare l'environnement, importe les solutions depuis Git et marque la base utilisée.
- `backup-dev-changes` exporte un snapshot de secours d'un environnement de développement sans pousser quoi que ce soit dans Git.
- `capture-dev-changes` bloque les captures obsolètes puis exporte les solutions modifiées vers la branche de feature.
- `single-run-promotion` promeut les changements mergés dans `main`.
