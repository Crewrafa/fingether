import Foundation

@MainActor
@Observable
final class CoupleViewModel {

    // MARK: - State

    var inviteCode = ""
    var isInCouple = false
    var couple: Couple?
    var partnerProfile: Profile?
    var isLoading = false
    var errorMessage: String?

    // MARK: - Actions

    func createCouple() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await CoupleService.createCouple()
            inviteCode = result.inviteCode
            couple = try await CoupleService.getCouple()
            isInCouple = true
        } catch {
            errorMessage = "No se pudo crear la pareja. Intenta de nuevo."
        }
    }

    func joinCouple(code: String) async {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            errorMessage = "Ingresa el codigo de invitacion de tu pareja."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await CoupleService.joinCouple(inviteCode: trimmedCode)
            couple = try await CoupleService.getCouple()
            if let couple {
                inviteCode = couple.inviteCode
            }
            isInCouple = true
            await loadPartner()
        } catch {
            errorMessage = mapCoupleError(error)
        }
    }

    func loadCouple() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let loadedCouple = try await CoupleService.getCouple() {
                couple = loadedCouple
                inviteCode = loadedCouple.inviteCode
                isInCouple = true
                await loadPartner()
            } else {
                isInCouple = false
                couple = nil
                partnerProfile = nil
            }
        } catch {
            errorMessage = "No se pudo cargar la informacion de pareja."
        }
    }

    func loadPartner() async {
        do {
            partnerProfile = try await CoupleService.getPartnerProfile()
        } catch {
            // Partner may not have joined yet
            partnerProfile = nil
        }
    }

    // MARK: - Private Helpers

    private func mapCoupleError(_ error: Error) -> String {
        let description = error.localizedDescription.lowercased()

        if description.contains("not found") || description.contains("invalid") {
            return "Codigo de invitacion invalido. Verifica e intenta de nuevo."
        }
        if description.contains("already") {
            return "Ya perteneces a una pareja o este codigo ya fue utilizado."
        }
        if description.contains("network") || description.contains("connection") {
            return "Sin conexion a internet. Verifica tu red e intenta de nuevo."
        }
        return "No se pudo unir a la pareja. Intenta de nuevo."
    }
}
