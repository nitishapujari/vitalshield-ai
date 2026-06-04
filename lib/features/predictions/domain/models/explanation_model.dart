enum FactorImpact {
  positive,
  neutral,
  negative,
}

class ContributingFactor {
  final String label;
  final FactorImpact impact;
  final double contributionPercent;
  final String description;
  final double scoreImprovementEstimate;

  const ContributingFactor({
    required this.label,
    required this.impact,
    required this.contributionPercent,
    required this.description,
    this.scoreImprovementEstimate = 0.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'label': label,
      'impact': impact.name,
      'contributionPercent': contributionPercent,
      'description': description,
      'scoreImprovementEstimate': scoreImprovementEstimate,
    };
  }

  factory ContributingFactor.fromMap(Map<String, dynamic> map) {
    return ContributingFactor(
      label: map['label'] ?? '',
      impact: FactorImpact.values.firstWhere(
        (e) => e.name == map['impact'],
        orElse: () => FactorImpact.neutral,
      ),
      contributionPercent: (map['contributionPercent'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] ?? '',
      scoreImprovementEstimate: (map['scoreImprovementEstimate'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PredictionExplanation {
  final List<ContributingFactor> factors;

  const PredictionExplanation({
    required this.factors,
  });

  Map<String, dynamic> toMap() {
    return {
      'factors': factors.map((x) => x.toMap()).toList(),
    };
  }

  factory PredictionExplanation.fromMap(Map<String, dynamic> map) {
    return PredictionExplanation(
      factors: List<ContributingFactor>.from(
        (map['factors'] as List<dynamic>? ?? []).map(
          (x) => ContributingFactor.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }
}
