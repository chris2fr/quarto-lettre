---
title: Test complet — Extension « Lettre »
author: Chris Mann
date: 7 juin 2026
ref: test-lettre-2026-06-07
lang: fr
place: Paris
---

[![Les Grands Voisins — Association d’intérêt général](_parts/logo/logo-lesgrandsvoisins-600-100-white.png)](https://www.lesgrandsvoisins.com)

---

Chris Mann  
7 place de l’Église  
92260 Fontenay-aux-Roses

Paris, le 7 juin 2026

Le développeur Quarto  
À qui de droit

## Test complet — Extension « Lettre »

réf. test-lettre-2026-06-07

Madame, Monsieur,

La présente “lettre” teste l’ensemble des fonctionnalités de l’extension **Lettre**[1] pour [Quarto](https://quarto.org). Elle couvre tous les éléments de mise en forme, quatre niveaux de titres et des images intégrées(Dupont 2022).

<figure>
<img src="_brand/logo/logo-lesgrandsvoisins-600-100-white.png" alt="Les Grands Voisins" />
<figcaption aria-hidden="true">Les Grands Voisins</figcaption>
</figure>

# Niveau 1 — Présentation générale

L’extension “**Lettre**” permet de rédiger des lettres formelles en *Markdown* et de les exporter vers sept formats de sortie simultanément. Voici un exemple de logo intégré dans le corps :

<figure>
<img src="logo-lesgrandsvoisins-900-150-white.png" alt="Logo Les Grands Voisins" />
<figcaption aria-hidden="true">Logo Les Grands Voisins</figcaption>
</figure>

> Une citation mise en valeur dans un bloc. Elle peut s’étendre sur plusieurs lignes et illustre la mise en forme d’un extrait ou d’une référence.

## Niveau 2 — Mise en forme du texte

Du texte en **gras**, en *italique*, en ***gras italique***, et du `code inline`. Un lien vers [Quarto](https://quarto.org) et une note de bas de page[2].

Liste non ordonnée :

- Élément A
- Élément B
  - Sous-élément B1
  - Sous-élément B2
- Élément C

Liste ordonnée(Dupont Group 2024) :

1.  Premier point
2.  Deuxième point
3.  Troisième point

## Niveau 2 — Tableaux

Tableau standard :

| Div          | Rôle                   |
|:-------------|:-----------------------|
| `::: header` | En-tête de page        |
| `::: from`   | Coordonnées expéditeur |
| `::: to`     | Adresse destinataire   |
| `::: body`   | Corps de la lettre     |

Image réduite à 40 % de la largeur :

<figure>
<img src="logo-lesgrandsvoisins-900-150-white.png" style="width:40.0%" alt="Logo réduit" />
<figcaption aria-hidden="true">Logo réduit</figcaption>
</figure>

### Niveau 3 — Tableau de facturation

<table id="tbl-facture" width="100%">
<thead>
<tr>
<th style="text-align: left;">Description</th>
<th style="text-align: center;">Prix unitaire</th>
<th style="text-align: center;">Quantité</th>
<th style="text-align: right;">Total</th>
</tr>
</thead>
<tbody>
<tr>
<td style="text-align: left;">Prestation A</td>
<td style="text-align: center;">100 €</td>
<td style="text-align: center;">2</td>
<td style="text-align: right;">200 €</td>
</tr>
<tr>
<td style="text-align: left;">Prestation B</td>
<td style="text-align: center;">50 €</td>
<td style="text-align: center;">3</td>
<td style="text-align: right;">150 €</td>
</tr>
<tr>
<td colspan="3" style="text-align: right;" data-border-top="solid 1px">
<strong>Total</strong></td>
<td style="text-align: right;"><strong>350 €</strong></td>
</tr>
</tbody>
</table>

### Niveau 3 — Bloc de code

Configuration YAML de l’extension :

``` yaml
format:
  lettre-html: default
  lettre-pdf: default
  lettre-typst: default
  lettre-docx: default
  lettre-odt: default
  lettre-md: default
  lettre-plain: default
```

Commande de rendu :

``` bash
quarto render lettre.qmd
```

#### Niveau 4 — Notes techniques

L’extension requiert **Quarto 1.9** ou supérieur. Les métadonnées YAML (`title`, `author`, `ref`, `lang`, `place`, `date`) sont réutilisables dans le document via `{{< meta clé >}}`.

Extrait de code Lua :

``` lua
function Div(el)
  if el.classes:includes("body") then
    return el.content
  end
end
```

En espérant que cette extension vous sera utile, je reste à votre disposition pour toute question ou suggestion, et vous adresse mes cordiales salutations.

Chris Mann

Dupont Group. 2024. *Other Thing*. Pamphlet No. 2. Recipient@example.com. Dupont@example.com. <https://example.com/dupont/otherthing>.

Dupont, Jean. 2022. *Something*. Handwritten note No. 3. Recipient@example.com. This is a volume. John@example.com. <https://example.com/something>.

[1] Un format de lettre français pour Quarto.

[2] Ceci est une deuxième note de bas de page.

---

[+33 7 81 81 18 11](tel:+33781811811) — <chris@lesgrandsvoisins.com>  
Siège : chez C. LHOMME - 146 bd de Montparnasse 75014 PARIS  
Association d’intérêt général de loi 1901 RNA W751240710 SIREN 832760102
