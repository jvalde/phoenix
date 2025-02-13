import SwiftUI
import PhoenixShared
import os.log

#if DEBUG && true
fileprivate var log = Logger(
	subsystem: Bundle.main.bundleIdentifier!,
	category: "MaxFeeConfiguration"
)
#else
fileprivate var log = Logger(OSLog.disabled)
#endif


struct MaxFeeConfiguration: View {
	
	let minimumBaseFee = Double(0)       // sat
	let maximumBaseFee = Double(100_000) // sat
	
	let minimumProportionalFee = Double(0)  // %
	let maximumProportionalFee = Double(50) // %
	
	enum FeeProblem {
		enum InvalidReason {
			case notANumber
			case belowMinimum
			case aboveMaximum
		}
		enum WarningReason {
			case belowRecommended
		}
		case invalid(InvalidReason)
		case warning(WarningReason)
	}
	
	@State var baseFee: String
	@State var parsedBaseFee: Result<Double, TextFieldCurrencyStylerError>
	@State var baseFeeProblem: FeeProblem?
	
	@State var proportionalFee: String
	@State var parsedProportionalFee: Result<NSNumber, TextFieldNumberStylerError>
	@State var proportionalFeeProblem: FeeProblem?
	
	let examplePayments: [Int64] = [1_000, 10_000, 100_000, 1_000_000]
	@State var examplePaymentsIdx = 1
	
	@State var firstAppearance = true
	
	@EnvironmentObject var deepLinkManager: DeepLinkManager
	@EnvironmentObject var smartModalState: SmartModalState
	
	enum ExampleHeight: Preference {}
	let exampleHeightReader = GeometryPreferenceReader(
		key: AppendValue<ExampleHeight>.self,
		value: { [$0.size.height] }
	)
	@State var exampleHeight: CGFloat? = nil
	
	var invalidBaseFee: FeeProblem.InvalidReason? {
		if case .invalid(let reason) = baseFeeProblem {
			return reason
		} else {
			return nil
		}
	}
	
	var invalidProportionalFee: FeeProblem.InvalidReason? {
		if case .invalid(let reason) = proportionalFeeProblem {
			return reason
		} else {
			return nil
		}
	}
	
	var baseFeeWarning: FeeProblem.WarningReason? {
		if case .warning(let reason) = baseFeeProblem {
			return reason
		} else {
			return nil
		}
	}
	
	var proportionalFeeWarning: FeeProblem.WarningReason? {
		if case .warning(let reason) = proportionalFeeProblem {
			return reason
		} else {
			return nil
		}
	}
	
	init() {
		if let maxFees = Prefs.shared.maxFees {
			
			let feeBaseFormatted = Utils.formatBitcoin(sat: maxFees.feeBaseSat, bitcoinUnit: .sat)
			self.parsedBaseFee = Result.success(Double(maxFees.feeBaseSat))
			self.baseFee = feeBaseFormatted.digits
			self.baseFeeProblem = nil
			
			let percent = Double(maxFees.feeProportionalMillionths) / Double(10_000)
			self.parsedProportionalFee = Result.success(NSNumber(value: percent))
			self.proportionalFee = formatProportionalFee(maxFees.feeProportionalMillionths)
			self.proportionalFeeProblem = nil
			
		} else {
			self.baseFee = ""
			self.parsedBaseFee = Result.failure(.emptyInput)
			self.baseFeeProblem = .invalid(.notANumber)
			
			self.proportionalFee = ""
			self.parsedProportionalFee = Result.failure(.emptyInput)
			self.proportionalFeeProblem = .invalid(.notANumber)
		}
	}
	
	// --------------------------------------------------
	// MARK: View Builders
	// --------------------------------------------------
	
	@ViewBuilder
	var body: some View {
		
		VStack(alignment: HorizontalAlignment.leading, spacing: 0) {
			
			Text("Max base fee (satoshis)")
				.padding(.leading, 8)
				.padding(.bottom, 6)
			
			HStack(alignment: VerticalAlignment.center, spacing: 0) {
				TextField(
					defaultBaseFee(),
					text: currencyStyler().amountProxy
				)
				.keyboardType(.decimalPad)
				.disableAutocorrection(true)
				.foregroundColor(invalidBaseFee != nil ? Color.appNegative : Color.primaryForeground)
				.padding([.top, .bottom], 8)
				.padding([.leading, .trailing], 16)
				
				// Clear button (appears when TextField's text is non-empty)
				Button {
					clearBaseFee()
				} label: {
					Image(systemName: "multiply.circle.fill")
						.foregroundColor(Color(UIColor.tertiaryLabel))
				}
				.isHidden(baseFee == "")
				.padding(.trailing, 8)
			}
			.overlay(
				RoundedRectangle(cornerRadius: 8)
					.stroke(Color.textFieldBorder, lineWidth: 1)
			)
			.padding(.bottom)
			
			Text("Max proportional fee (%)")
				.padding(.leading, 8)
				.padding(.bottom, 6)
			
			HStack(alignment: VerticalAlignment.center, spacing: 0) {
				TextField(
					defaultProportionalFee(),
					text: percentParser().amountProxy
				)
				.keyboardType(.decimalPad)
				.disableAutocorrection(true)
				.foregroundColor(invalidProportionalFee != nil ? Color.appNegative : Color.primaryForeground)
				.padding([.top, .bottom], 8)
				.padding([.leading, .trailing], 16)
				
				// Clear button (appears when TextField's text is non-empty)
				Button {
					clearProportionalFee()
				} label: {
					Image(systemName: "multiply.circle.fill")
						.foregroundColor(Color(UIColor.tertiaryLabel))
				}
				.isHidden(proportionalFee == "")
				.padding(.trailing, 8)
			}
			.overlay(
				RoundedRectangle(cornerRadius: 8)
					.stroke(Color.textFieldBorder, lineWidth: 1)
			)
			.padding(.bottom)
			
			footer
				.padding(.top, 8)
				.padding(.bottom, 24)
			
			HStack {
				Spacer()
				
				Button("Cancel") {
					didTapCancelButton()
				}
				.padding(.trailing)
				
				Button("Save") {
					didTapSaveButton()
				}
				.disabled(invalidBaseFee != nil || invalidProportionalFee != nil)
			}
			.font(.title2)
		}
		.padding()
		.onAppear {
			onAppear()
		}
		.onChange(of: baseFee) { _ in
			baseFeeDidChange()
		}
		.onChange(of: proportionalFee) { _ in
			proportionalFeeDidChange()
		}
	}

	@ViewBuilder
	var footer: some View {
		
		ZStack(alignment: Alignment.topLeading) {
			if let invalidBaseFee = invalidBaseFee, invalidBaseFee != .notANumber {
				example(pseudoHide: true)
				errorMessage(invalidBaseFee, isBaseFee: true)
			} else if let invalidProportionalFee = invalidProportionalFee, invalidProportionalFee != .notANumber {
				example(pseudoHide: true)
				errorMessage(invalidProportionalFee, isBaseFee: false)
			} else if let baseFeeWarning = baseFeeWarning {
				example(pseudoHide: true)
				warningMessage(baseFeeWarning, isBaseFee: true)
			} else if let proportionalFeeWarning = proportionalFeeWarning {
				example(pseudoHide: true)
				warningMessage(proportionalFeeWarning, isBaseFee: false)
			} else {
				example(pseudoHide: false)
			}
		}
	}

	@ViewBuilder
	func errorMessage(_ reason: FeeProblem.InvalidReason, isBaseFee: Bool) -> some View {
		
		Group {
			if isBaseFee {
				switch reason {
					case .belowMinimum:
						let minSats = Utils.formatBitcoin(sat: Int64(minimumBaseFee), bitcoinUnit: .sat).string
						Text("Base fee must be at least \(minSats).")
					case .aboveMaximum:
						let maxSats = Utils.formatBitcoin(sat: Int64(maximumBaseFee), bitcoinUnit: .sat).string
						Text("Maximum base fee is \(maxSats).")
					default:
						EmptyView()
				}
			} else {
				switch reason {
					case .belowMinimum:
						let minPercent = formatPercent_noFractionDigits(minimumProportionalFee / 100.0)
						Text("Proportianal fee must be at least \(minPercent).")
					case .aboveMaximum:
						let maxPercent = formatPercent_noFractionDigits(maximumProportionalFee / 100.0)
						Text("Maximum proportional fee is \(maxPercent).")
					default:
						EmptyView()
				}
			}
		}
		.font(.subheadline)
		.foregroundColor(.appNegative)
	}
	
	@ViewBuilder
	func warningMessage(_ reason: FeeProblem.WarningReason, isBaseFee: Bool) -> some View {
		
		Group {
			if isBaseFee {
				let recommended = defaultMaxFees().feeBaseSat
				let minSats = Utils.formatBitcoin(sat: recommended, bitcoinUnit: .sat).string
				Text("With configured proportional fee, we recommend a base fee of at least \(minSats).")
			} else {
				let recommended = defaultMaxFees().feeProportionalMillionths
				let minPercent = formatProportionalFee(recommended)
				Text("With configured base fee, we recommend a proportional fee of at least \(minPercent)%.")
			}
		}
		.font(.subheadline)
		.foregroundColor(.primary)
	}
	
	@ViewBuilder
	func example(pseudoHide: Bool) -> some View {
		
		// |      example payment :   10,000 sat     - + |
		// |             base fee :      100 sat         |
		// |     proportional fee :       30 sat         |
		// | ------------------------------------------- |
		// |              max fee :      130 sat (1.3%)  |
		
		let pseudoClear = Color(UIColor.systemBackground)
		ZStack(alignment: Alignment.topTrailing) {
			
			GeometryReader { geometry in
				
				let column0Width: CGFloat = geometry.size.width / 4.0 * 2.0
				let column1Width: CGFloat = geometry.size.width / 4.0 * 1.25
				let column2Width: CGFloat = geometry.size.width / 4.0 * 0.75
				
				let columns: [GridItem] = [
					GridItem(.fixed(column0Width), spacing: 0, alignment: .trailing),
					GridItem(.fixed(column1Width), spacing: 0, alignment: .trailing),
					GridItem(.fixed(column2Width), spacing: 0, alignment: .leading)
				]
				
				VStack(alignment: HorizontalAlignment.center, spacing: 8) {
					
					LazyVGrid(columns: columns, spacing: 8) {
						
						HStack(alignment: VerticalAlignment.center, spacing: 0) {
							Text("example payment")
								.multilineTextAlignment(.trailing)
							Text(verbatim: " : ")
						}
						Text(examplePaymentAmountString())
						Text(verbatim: " ")
						
						HStack(alignment: VerticalAlignment.center, spacing: 0) {
							Text("max base fee")
								.multilineTextAlignment(.trailing)
							Text(verbatim: " : ")
						}
						Text(exampleBaseFeeString())
						Text(verbatim: " ")
						
						HStack(alignment: VerticalAlignment.center, spacing: 0) {
							Text("max proportional fee")
								.multilineTextAlignment(.trailing)
							Text(verbatim: " : ")
						}
						Text(exampleProportionalFeeString())
						Text(verbatim: " ")
					
					} // </LazyVGrid>
					.font(.footnote)
					.foregroundColor(pseudoHide ? pseudoClear : .secondary)
					
					if pseudoHide {
						Rectangle()
							 .fill(Color(UIColor.systemBackground))
							 .frame(width: 1, height: 2)
					} else {
						Divider()
							.frame(height: 2)
					}
					
					LazyVGrid(columns: columns, spacing: 8) {
						
						HStack(alignment: VerticalAlignment.center, spacing: 0) {
							Text("max fee")
								.multilineTextAlignment(.trailing)
							Text(verbatim: " : ")
						}
						Text(exampleMaxFeeString())
						Text(verbatim: " (\(exampleMaxPercentString()))")
						
					} // </LazyVGrid>
					.font(.footnote)
					.foregroundColor(pseudoHide ? pseudoClear : .secondary)
					
				} // </VStack>
				.read(exampleHeightReader)
				
			} // </GeometryReader>
			.assignMaxPreference(for: exampleHeightReader.key, to: $exampleHeight)
			.frame(height: exampleHeight)
			
			HStack(alignment: VerticalAlignment.top, /*horizontal-*/spacing: 32) {
				Button {
					decrementExamplePaymentsIdx()
				} label: {
					Text(verbatim: "-")
				}
				.disabled(examplePaymentsIdx == 0)
				
				Button {
					incrementExamplePaymentsIdx()
				} label: {
					Text(verbatim: "+")
				}
				.disabled(examplePaymentsIdx+1 == examplePayments.count)
				
			} // </HStack>
			.font(.headline)
			.isHidden(pseudoHide)
			
		} // </ZStack>
	}
	
	// --------------------------------------------------
	// MARK: View Helpers
	// --------------------------------------------------
	
	func formatPercent_noFractionDigits(_ value: Double) -> String {
		
		let formatter = NumberFormatter()
		formatter.numberStyle = .percent
		formatter.minimumFractionDigits = 0
		formatter.maximumFractionDigits = 0
		
		return formatter.string(from: NSNumber(value: value))!
	}
	
	func defaultBaseFee() -> String {
		
		let fees = defaultMaxFees()
		let formatted = Utils.formatBitcoin(sat: fees.feeBaseSat, bitcoinUnit: .sat)
		return formatted.digits
	}
	
	func defaultProportionalFee() -> String {
		
		let fees = defaultMaxFees()
		return formatProportionalFee(fees.feeProportionalMillionths)
	}
	
	func examplePaymentAmount() -> Lightning_kmpMilliSatoshi {
		
		let sat = examplePayments[examplePaymentsIdx]
		return Lightning_kmpMilliSatoshi(sat: Bitcoin_kmpSatoshi(sat: sat))
	}
	
	func examplePaymentAmountString() -> String {
		return Utils.formatBitcoin(msat: examplePaymentAmount(), bitcoinUnit: .sat, policy: .hideMsats).string
	}
	
	func exampleBaseFee() -> Lightning_kmpMilliSatoshi {
		
		if invalidBaseFee == nil, case .success(let amount) = parsedBaseFee {
			let msat = Int64(amount * 1_000.0)
			return Lightning_kmpMilliSatoshi(msat: msat)
		} else {
			let defaultFees = defaultMaxFees()
			return Lightning_kmpMilliSatoshi(sat: Bitcoin_kmpSatoshi(sat: defaultFees.feeBaseSat))
		}
	}
	
	func exampleBaseFeeString() -> String {
		return Utils.formatBitcoin(msat: exampleBaseFee(), bitcoinUnit: .sat, policy: .hideMsats).string
	}
	
	func exampleProportionalFee() -> Lightning_kmpMilliSatoshi {
		
		let paymentAmount = Double(examplePaymentAmount().msat)
		
		if invalidProportionalFee == nil, case .success(let number) = parsedProportionalFee {
			// Example:
			// number: 0.5 <- is a a percent, i.e. 0.5%
			// toPercent: 0.5 / 100 = 0.005
			let percent = number.doubleValue / Double(100)
			let msat = Int64(paymentAmount * percent)
			return Lightning_kmpMilliSatoshi(msat: msat)
		} else {
			let defaultFees = defaultMaxFees()
			let percent = Double(defaultFees.feeProportionalMillionths) / Double(1_000_000)
			let msat = Int64(paymentAmount * percent)
			return Lightning_kmpMilliSatoshi(msat: msat)
		}
	}
	
	func exampleProportionalFeeString() -> String {
		return Utils.formatBitcoin(msat: exampleProportionalFee(), bitcoinUnit: .sat, policy: .hideMsats).string
	}
	
	func exampleMaxFee() -> Lightning_kmpMilliSatoshi {
		
		let msat = exampleBaseFee().msat + exampleProportionalFee().msat
		return Lightning_kmpMilliSatoshi(msat: msat)
	}
	
	func exampleMaxFeeString() -> String {
		return Utils.formatBitcoin(msat: exampleMaxFee(), bitcoinUnit: .sat, policy: .hideMsats).string
	}
	
	func exampleMaxPercent() -> Double {
		
		let numerator = exampleMaxFee()
		let denominator = examplePaymentAmount()
		
		return Double(numerator.msat) / Double(denominator.msat)
	}
	
	func exampleMaxPercentString() -> String {
		
		let raw = exampleMaxPercent()
		let percent = raw * Double(100)
		
		let formatter = NumberFormatter()
		formatter.numberStyle = .percent
		
		// This doesn't work.
	//	formatter.usesSignificantDigits = true
	//	formatter.minimumSignificantDigits = 3
	//	formatter.maximumSignificantDigits = 3
	
		if percent < 0 { // 0.XY
			formatter.minimumFractionDigits = 2
			formatter.maximumFractionDigits = 2
		} else if percent < 10 { // A.XY
			formatter.minimumFractionDigits = 2
			formatter.maximumFractionDigits = 2
		} else if percent < 100 { // AB.X
			formatter.minimumFractionDigits = 1
			formatter.maximumFractionDigits = 1
		} else { // ABC
			formatter.minimumFractionDigits = 0
			formatter.maximumFractionDigits = 0
		}
	
		return formatter.string(from: NSNumber(value: exampleMaxPercent())) ?? ""
	}
	
	func currencyStyler() -> TextFieldCurrencyStyler {
		return TextFieldCurrencyStyler(
			currency: Currency.bitcoin(.sat),
			amount: $baseFee,
			parsedAmount: $parsedBaseFee,
			hideMsats: false
		)
	}
	
	func percentParser() -> TextFieldNumberStyler {
		return TextFieldNumberStyler(
			formatter: NumberFormatter(),
			amount: $proportionalFee,
			parsedAmount: $parsedProportionalFee
		)
	}
	
	// --------------------------------------------------
	// MARK: Notifications
	// --------------------------------------------------
	
	func onAppear() {
		log.trace("onAppear()")
		
		if firstAppearance {
			firstAppearance = false
			
			if let deepLink = deepLinkManager.deepLink, deepLink == .liquiditySettings {
				// Reached our destination
				DispatchQueue.main.async { // iOS 14 issues workaround
					deepLinkManager.unbroadcast(deepLink)
				}
			}
		}
	}
	
	// --------------------------------------------------
	// MARK: Actions
	// --------------------------------------------------
	
	func baseFeeDidChange() {
		log.trace("baseFeeDidChange()")
		
		switch parsedBaseFee {
		case .failure:
			if baseFee.isEmpty {
				baseFeeProblem = nil // user choosing default value
			} else {
				baseFeeProblem = .invalid(.notANumber)
			}
		case .success(let configuredBaseFee):
			if configuredBaseFee < minimumBaseFee {
				baseFeeProblem = .invalid(.belowMinimum)
			} else if configuredBaseFee > maximumBaseFee {
				baseFeeProblem = .invalid(.aboveMaximum)
			} else {
				baseFeeProblem = nil
				checkForWarnings()
			}
		}
	}
	
	func proportionalFeeDidChange() {
		log.trace("proportionalFeeDidChange()")
		
		switch parsedProportionalFee {
		case .failure:
			if proportionalFee.isEmpty {
				proportionalFeeProblem = nil // user choosing default value
			} else {
				proportionalFeeProblem = .invalid(.notANumber)
			}
		case .success(let number):
			let percent = number.doubleValue
			if percent < 0 {
				proportionalFeeProblem = .invalid(.belowMinimum)
			}
			else if percent > maximumProportionalFee {
				proportionalFeeProblem = .invalid(.aboveMaximum)
			} else {
				proportionalFeeProblem = nil
				checkForWarnings()
			}
		}
	}
	
	func checkForWarnings() {
		
		log.trace("clearBaseFee()")
		
		guard
			invalidBaseFee == nil,
			let configuredBaseFee = try? parsedBaseFee.get(),
			invalidProportionalFee == nil,
			let configuredPercent = try? parsedProportionalFee.get()
		else {
			return
		}
		
		let defaultMaxFees = defaultMaxFees()
		let defaultMaxBaseFee = Double(defaultMaxFees.feeBaseSat)
		let defaultMaxProportionalPercent = Double(defaultMaxFees.feeProportionalMillionths) / 10_000.0
		
		do {
			// IF configuredBaseFee is "significantly" above the default max value,
			// AND the configuredPercent is below the default max value,
			// THEN we display a warning.
			
			let baseFeeThreshold = defaultMaxBaseFee + 300
			
			var warn = false
			if configuredBaseFee >= baseFeeThreshold {
				if configuredPercent.doubleValue < defaultMaxProportionalPercent {
					warn = true
				}
			}
			proportionalFeeProblem = warn ? .warning(.belowRecommended) : nil
		}
		do {
			// IF configuredProportionalPercent is "significantly" above the default max value,
			// AND the configuredBaseFee is below the default max value,
			// THEN we display a warning.
		
			let proportionalPercentThreshold = defaultMaxProportionalPercent + 0.2 // 0.2% == 0.002
			
			var warn = false
			if configuredPercent.doubleValue >= proportionalPercentThreshold {
				if configuredBaseFee < defaultMaxBaseFee {
					warn = true
				}
			}
			baseFeeProblem = warn ? .warning(.belowRecommended) :  nil
		}
	}
	
	func clearBaseFee() {
		log.trace("clearBaseFee()")
		
		parsedBaseFee = .failure(.emptyInput)
		baseFee = "" // triggers `baseFeeDidChange()`
	}
	
	func clearProportionalFee() {
		log.trace("clearProportionalFee()")
		
		parsedProportionalFee = .failure(.emptyInput)
		proportionalFee = "" // triggers `proportionalFeeDidChange()`
	}
	
	func decrementExamplePaymentsIdx() {
		log.trace("decrementExamplePaymentsIdx")
		
		guard examplePaymentsIdx > 0 else {
			return
		}
		examplePaymentsIdx -= 1
	}
	
	func incrementExamplePaymentsIdx() {
		log.trace("incrementExamplePaymentsIdx")
		
		guard examplePaymentsIdx + 1 < examplePayments.count else {
			return
		}
		examplePaymentsIdx += 1
	}
	
	func didTapCancelButton() {
		log.trace("didTapCancelButton()")
		
		smartModalState.close()
	}
	
	func didTapSaveButton() {
		log.trace("didTapSaveButton()")
		
		// Reminder: Our state variables:
		//
		// parsedBaseFee: Result<Double, TextFieldCurrencyStylerError>
		// parsedProportionalFee: Result<NSNumber, TextFieldNumberParserError>
		
		var shouldSave = false
		
		var newBaseFee_sat: Int64? = nil
		var newProportionalFee_millionths: Int64? = nil
		
		if invalidBaseFee == nil,
			let newBaseFee_double = try? parsedBaseFee.get(),
			newBaseFee_double > 0
		{
			newBaseFee_sat = Int64(newBaseFee_double)
			shouldSave = true
		}
		if invalidProportionalFee == nil,
			let newProportionalFee_number = try? parsedProportionalFee.get()
		{
			let newProportionalFee_double = newProportionalFee_number.doubleValue
			if newProportionalFee_double > 0 {
			
				// Example:
				// newProportionalFee_double: 0.5 <- is a a percent, i.e. 0.5%
				// toNumber: 0.5 / 100 = 0.005
				// toMillionths: 0.005 * 1,000,000 = 5,000
				//
				// Or, to simplify:
				// toMillionths: 0.5 * 10,000 = 5,000
				
				newProportionalFee_millionths = Int64(newProportionalFee_double * Double(10_000))
				shouldSave = true
			}
		}
		
		if shouldSave {
			let defaults = defaultMaxFees()
			Prefs.shared.maxFees = MaxFees(
				feeBaseSat: newBaseFee_sat ?? defaults.feeBaseSat,
				feeProportionalMillionths: newProportionalFee_millionths ?? defaults.feeProportionalMillionths
			)
		} else {
			Prefs.shared.maxFees = nil
		}
		
		smartModalState.close()
	}
}
