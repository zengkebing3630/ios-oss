import Foundation
import KsApi
import Prelude
import ReactiveSwift

public protocol ManagePledgeSummaryViewViewModelInputs {
  func configureWith(_ project: Project)
}

public protocol ManagePledgeSummaryViewViewModelOutputs {
  var backerNumberText: Signal<String, Never> { get }
  var backingDateText: Signal<String, Never> { get }
  var pledgeAmountText: Signal<NSAttributedString, Never> { get }
  var shippingAmountText: Signal<NSAttributedString, Never> { get }
  var shippingLocationStackViewIsHidden: Signal<Bool, Never> { get }
  var shippingLocationText: Signal<String, Never> { get }
  var totalAmountText: Signal<NSAttributedString, Never> { get }
}

public protocol ManagePledgeSummaryViewViewModelType {
  var inputs: ManagePledgeSummaryViewViewModelInputs { get }
  var outputs: ManagePledgeSummaryViewViewModelOutputs { get }
}

public class ManagePledgeSummaryViewViewModel: ManagePledgeSummaryViewViewModelType,
  ManagePledgeSummaryViewViewModelInputs, ManagePledgeSummaryViewViewModelOutputs {
  public init() {
    let backing = self.projectSignal
      .map { $0.personalization.backing }
      .skipNil()

    let projectAndBacking = self.projectSignal
      .zip(with: backing)

    self.backerNumberText = backing
      .map { "Backer #\($0.sequence)" }

    self.backingDateText = backing
      .map(formattedPledgeDate)

    self.pledgeAmountText = projectAndBacking
      .map { attributedCurrency(with: $0.0, amount: $0.1.amount) }
      .skipNil()

    let shippingAmount = backing
      .map { Double($0.shippingAmount ?? 0) }

    self.shippingAmountText = self.projectSignal
      .combineLatest(with: shippingAmount)
      .map { shippingValue(with: $0.0, with: $0.1) }
      .skipNil()

    self.totalAmountText = projectAndBacking
      .combineLatest(with: shippingAmount)
      .map(unpack)
      .map { project, backing, shippingAmount in
        attributedCurrency(with: project, amount: backing.amount + shippingAmount)
      }
      .skipNil()

    self.shippingLocationText = backing.ignoreValues()
      .map { "Shipping: Australia" }

    self.shippingLocationStackViewIsHidden = self.projectSignal
      .map(shouldHideShippingLocationStackView)
  }

  private let (projectSignal, projectObserver) = Signal<Project, Never>.pipe()
  public func configureWith(_ project: Project) {
    self.projectObserver.send(value: project)
  }

  public let backerNumberText: Signal<String, Never>
  public let backingDateText: Signal<String, Never>
  public let pledgeAmountText: Signal<NSAttributedString, Never>
  public let shippingAmountText: Signal<NSAttributedString, Never>
  public let shippingLocationStackViewIsHidden: Signal<Bool, Never>
  public let shippingLocationText: Signal<String, Never>
  public let totalAmountText: Signal<NSAttributedString, Never>

  public var inputs: ManagePledgeSummaryViewViewModelInputs { return self }
  public var outputs: ManagePledgeSummaryViewViewModelOutputs { return self }
}

private func shouldHideShippingLocationStackView(_ project: Project) -> Bool {
  guard let backing = project.personalization.backing,
    let _ = backing.rewardId else {
    return true
  }
  if let reward = backing.reward {
    return !reward.shipping.enabled || reward.isNoReward
  }

  return backing.locationId.isNil
}

private func formattedPledgeDate(_ backing: Backing) -> String {
  let formattedDate = Format.date(secondsInUTC: backing.pledgedAt, dateStyle: .long, timeStyle: .none)
  return "As of \(formattedDate)"
}

private func attributedCurrency(with project: Project, amount: Double) -> NSAttributedString? {
  let defaultAttributes = checkoutCurrencyDefaultAttributes()
    .withAllValuesFrom([.foregroundColor: UIColor.ksr_green_500])
  let superscriptAttributes = checkoutCurrencySuperscriptAttributes()
  guard
    let attributedCurrency = Format.attributedCurrency(
      amount,
      country: project.country,
      omitCurrencyCode: project.stats.omitUSCurrencyCode,
      defaultAttributes: defaultAttributes,
      superscriptAttributes: superscriptAttributes
    ) else { return nil }

  let combinedAttributes = defaultAttributes
    .withAllValuesFrom(superscriptAttributes)

  return Format.attributedAmount(attributes: combinedAttributes) + attributedCurrency
}

private func shippingValue(with project: Project, with shippingRuleCost: Double) -> NSAttributedString? {
  let defaultAttributes = checkoutCurrencyDefaultAttributes()
  let superscriptAttributes = checkoutCurrencySuperscriptAttributes()
  guard
    let attributedCurrency = Format.attributedCurrency(
      shippingRuleCost,
      country: project.country,
      omitCurrencyCode: project.stats.omitUSCurrencyCode,
      defaultAttributes: defaultAttributes,
      superscriptAttributes: superscriptAttributes
    ) else { return nil }

  let combinedAttributes = defaultAttributes.merging(superscriptAttributes) { _, new in new }

  return Format.attributedPlusSign(combinedAttributes) + attributedCurrency
}
