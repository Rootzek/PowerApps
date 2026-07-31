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

### Convention de nommage des environnements de développement (scalabilité)

Les workflows `prepare-dev-environment`, `capture-dev-changes` et `backup-dev-changes` ne codent plus en dur une liste fixe de développeurs. Ils utilisent une convention de nommage résolue dynamiquement par la composite action `.github/actions/resolve-dev-environment`.

Convention:

- La clé d'environnement doit respecter le format `dev_<slug>` (lettres minuscules et chiffres uniquement), par exemple `dev_user1`, `dev_user3`, `dev_alice`.
- Pour une clé `dev_<slug>`, les variables associées doivent s'appeler `DEV_<SLUG_MAJUSCULE>_ENV_URL` et `DEV_<SLUG_MAJUSCULE>_ENV_ID`. Exemple: `dev_user3` → `DEV_USER3_ENV_URL` / `DEV_USER3_ENV_ID`.
- Un GitHub Environment du même nom (`dev_user3`) doit exister dans les paramètres du dépôt, pour porter les protections et secrets propres à cet environnement.

Si une variable attendue est manquante, le workflow échoue immédiatement avec un message indiquant les deux noms de variables attendus, plutôt que de retomber silencieusement sur un autre environnement.

### Onboarding d'un nouveau développeur

Ajouter un développeur ne nécessite plus de modifier les workflows. Il suffit de:

1. Créer un GitHub Environment nommé `dev_<slug>` dans les paramètres du dépôt.
2. Ajouter les variables `DEV_<SLUG_MAJUSCULE>_ENV_URL` et `DEV_<SLUG_MAJUSCULE>_ENV_ID` (au niveau du dépôt ou de cet Environment).
3. Ajouter, si nécessaire, les secrets propres à cet Environment.
4. Lancer `prepare-dev-environment` en indiquant `dev_<slug>` comme valeur du champ `environment` (champ texte libre, plus une liste déroulante fixe).

## Gestion des variables d'environnement

Chaque solution peut déclarer ses variables d'environnement Power Apps dans des fichiers de deployment settings versionnés dans Git. Ces fichiers sont appliqués automatiquement à chaque déploiement par le pipeline, sans saisie manuelle.

### Structure des fichiers

Pour chaque solution, les fichiers de settings sont organisés par environnement cible :

```
solutions/
  <NomDeLaSolution>/
    src/                    # code source Power Apps (existant)
    env-settings/
      dev.json
      qa.json
      prep.json
      prod.json
```

### Format d'un fichier de settings

Chaque fichier suit le format standard Power Platform :

```json
{
  "EnvironmentVariables": [
    {
      "SchemaName": "mp_NomDeVariable",
      "Value": "valeur-littérale-pour-cet-environnement"
    },
    {
      "SchemaName": "mp_CleApi",
      "Value": "${NOM_DU_SECRET_GITHUB}"
    }
  ],
  "ConnectionReferences": []
}
```

- Les valeurs **non-sensibles** (URL de portail, feature flags, etc.) sont inscrites directement dans le fichier JSON.
- Les valeurs **sensibles** (clés API, mots de passe, etc.) utilisent un placeholder au format `${NOM_DU_SECRET}`. Ce placeholder est remplacé par la vraie valeur au moment de l'exécution du pipeline, en lisant un GitHub Secret ou une GitHub Variable.

### Ajouter une nouvelle variable d'environnement

1. **Créer la variable dans Power Apps** via Power Apps Studio ou le portail maker (type `string`, `number`, etc.).

2. **Ajouter l'entrée dans les fichiers de settings** pour chaque environnement concerné (`dev.json`, `qa.json`, `prep.json`, `prod.json`) :
   - Pour une valeur non-sensible : écrire la valeur directement.
   - Pour une valeur sensible : écrire un placeholder `${MON_SECRET}`.

3. **Si un placeholder est utilisé**, ajouter le secret ou la variable correspondante dans GitHub :
   - GitHub Secrets → `Settings > Secrets and variables > Actions > Secrets`
   - GitHub Variables → `Settings > Secrets and variables > Actions > Variables`
   - Utiliser un nom de variable ou de secret distinct par environnement si les valeurs diffèrent (ex. : `QA_API_KEY`, `PROD_API_KEY`).

4. **Déclarer l'injection dans le workflow** : dans `single-run-promotion.yml` et `deploy-from-manifest.yml`, repérer le step `Prepare deployment settings` du job correspondant à l'environnement et ajouter une ligne `export` pour chaque nouveau placeholder :

   ```yaml
   - name: Prepare deployment settings for ${{ matrix.name }}
     id: settings
     shell: bash
     run: |
       FILE="solutions/${{ matrix.name }}/env-settings/qa.json"
       if [ -f "$FILE" ]; then
         export MON_SECRET="${{ secrets.QA_MON_SECRET }}"
         export MA_VARIABLE="${{ vars.QA_MA_VARIABLE }}"
         envsubst < "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
         ...
   ```

5. **Commit et merger** les modifications de fichiers JSON et de workflows sur `main`. Le pipeline appliquera les nouvelles valeurs dès le prochain déploiement.

### Modifier la valeur d'une variable existante

- **Valeur non-sensible** : modifier directement la valeur dans le fichier JSON de l'environnement concerné, puis commit.
- **Valeur sensible** : mettre à jour le GitHub Secret ou la GitHub Variable correspondant dans les paramètres du dépôt. Aucune modification de fichier Git n'est nécessaire.

### Supprimer une variable d'environnement

1. Retirer l'entrée correspondante dans tous les fichiers `env-settings/<env>.json` concernés.
2. Si un placeholder était utilisé, supprimer la ligne `export` dans les steps d'injection des workflows, ainsi que le GitHub Secret ou Variable associé.
3. Supprimer la variable dans Power Apps Studio si elle n'est plus utilisée par aucune solution.
4. Commit et merger sur `main`.

### Déclarer qu'une solution a des settings (manifest)

Le champ optionnel `has_env_settings: true` dans les fichiers `manifests/<env>/release.yml` et `manifests/releases/current.yml` sert à documenter qu'une solution utilise des variables d'environnement. Le pipeline détecte automatiquement la présence du fichier JSON au runtime, donc ce champ n'est pas obligatoire pour le bon fonctionnement — il est informatif.

```yaml
solutions:
  - name: "MainSolution"
    order: 10
    has_env_settings: true
```
