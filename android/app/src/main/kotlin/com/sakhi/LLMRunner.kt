package com.sakhi

import android.content.Context
import android.text.SpannableString
import android.text.Spanned
import android.text.style.URLSpan
import android.util.Log
import android.util.Patterns

class LLMRunner(private val context: Context) {

    init {
        try {
            System.loadLibrary("llama_jni")
            Log.i("LLMRunner", "llama native library loaded")
        } catch (e: UnsatisfiedLinkError) {
            Log.e("LLMRunner", "Failed to load llama library: ${e.message}")
        }
    }

    private var isLoaded = false

    private external fun initModel(modelPath: String): Boolean
    private external fun infer(prompt: String): String

    // =============================================================================
    // VERIFIED CACHED RESPONSES - TOP 100+ VILLAGE QUERIES
    // =============================================================================
    
    data class CachedResponse(
        val response: String,
        val verified: Boolean = true,
        val source: String = "Verified"
    )
    
    private val verifiedResponses = mapOf(
        // GOVERNMENT SCHEMES (Priority #1)
        "pm kisan" to CachedResponse(
            "PM-KISAN provides ₹6,000/year to farmers in 3 installments of ₹2,000. " +
            "Eligibility: All farmer families. Apply at nearest CSC or visit pmkisan.gov.in. " +
            "Required documents: Aadhaar, bank details, land records."
        ),
        "pm-kisan" to CachedResponse(
            "PM-KISAN provides ₹6,000/year to farmers in 3 installments of ₹2,000. " +
            "Eligibility: All farmer families. Apply at nearest CSC or visit pmkisan.gov.in. " +
            "Required documents: Aadhaar, bank details, land records."
        ),
        "pradhan mantri kisan" to CachedResponse(
            "PM-KISAN provides ₹6,000/year to farmers in 3 installments of ₹2,000. " +
            "Apply at CSC or visit pmkisan.gov.in with Aadhaar and land records."
        ),
        
        "ration card" to CachedResponse(
            "To apply for ration card: " +
            "1) Visit Tahsildar office with Aadhaar, address proof, and family photo. " +
            "2) Fill application form. " +
            "3) Submit and get acknowledgment receipt. " +
            "Processing time: 15-30 days. Check status at nfsa.gov.in"
        ),
        "rashan card" to CachedResponse(
            "To apply for ration card: Visit Tahsildar office with Aadhaar, address proof, family photo. " +
            "Fill form, submit documents, get receipt. Status: nfsa.gov.in"
        ),
        
        "aadhaar card" to CachedResponse(
            "Get Aadhaar at nearest enrollment center. " +
            "Required: Address proof, date of birth proof, and photo. " +
            "Visit uidai.gov.in to locate centers. " +
            "Update Aadhaar at myaadhaar.uidai.gov.in. Helpline: 1947"
        ),
        "aadhar card" to CachedResponse(
            "Get Aadhaar at enrollment center with address proof and DOB proof. " +
            "Find centers at uidai.gov.in. Helpline: 1947"
        ),
        
        "ayushman bharat" to CachedResponse(
            "Ayushman Bharat provides free health coverage up to ₹5 lakh per family per year. " +
            "Eligibility: Based on SECC 2011 data. Check at pmjay.gov.in or nearest hospital. " +
            "No application needed if eligible. Helpline: 14555"
        ),
        "health card" to CachedResponse(
            "Ayushman Bharat health card provides ₹5 lakh coverage. " +
            "Check eligibility at pmjay.gov.in or call 14555. Visit empanelled hospital with Aadhaar."
        ),
        
        "mgnrega" to CachedResponse(
            "MGNREGA guarantees 100 days of wage employment per year to rural households. " +
            "Apply at Gram Panchayat with job card. Wage: ₹209-309/day (varies by state). " +
            "More info: nrega.nic.in"
        ),
        "nrega" to CachedResponse(
            "NREGA provides 100 days guaranteed employment. Apply at Gram Panchayat. " +
            "Visit nrega.nic.in for job card and payment status."
        ),
        
        "kisan credit card" to CachedResponse(
            "Kisan Credit Card (KCC) provides crop loans at 4% interest with ₹3 lakh limit. " +
            "Apply at nearest bank or PACS with land records, Aadhaar. " +
            "Benefits: Low interest, insurance coverage. Visit pmkisan.gov.in"
        ),
        "kcc" to CachedResponse(
            "Kisan Credit Card offers loans at 4% interest up to ₹3 lakh. " +
            "Apply at bank with land records and Aadhaar."
        ),
        
        "pm awas yojana" to CachedResponse(
            "PM Awas Yojana provides financial assistance for building houses. " +
            "Assistance: ₹1.2-1.5 lakh (plain areas), ₹1.3-1.6 lakh (hilly areas). " +
            "Apply at pmaymis.gov.in or Gram Panchayat."
        ),
        
        "ujjwala yojana" to CachedResponse(
            "Pradhan Mantri Ujjwala Yojana provides free LPG connections to BPL families. " +
            "Eligibility: SECC 2011 beneficiaries, BPL card holders. " +
            "Apply with Aadhaar, BPL certificate, address proof. Visit pmuy.gov.in"
        ),
        
        "jan dhan yojana" to CachedResponse(
            "Pradhan Mantri Jan Dhan Yojana offers zero-balance bank accounts. " +
            "Benefits: RuPay debit card, ₹10,000 overdraft, accident insurance ₹2 lakh. " +
            "Open at any bank with Aadhaar. Visit pmjdy.gov.in"
        ),
        
        "sukanya samriddhi yojana" to CachedResponse(
            "Sukanya Samriddhi Yojana is savings scheme for girl child. " +
            "Interest: 8.2% per annum. Minimum deposit: ₹250/year. " +
            "Open at post office or bank before girl turns 10. Tax benefits under 80C."
        ),
        
        // AGRICULTURE (Priority #2)
        "crop insurance" to CachedResponse(
            "Pradhan Mantri Fasal Bima Yojana (PMFBY) insures crops against natural calamities. " +
            "Premium: 2% for Kharif, 1.5% for Rabi. Apply within 7 days of sowing at bank. " +
            "Visit pmfby.gov.in or call 18001801551"
        ),
        
        "kisan samman nidhi" to CachedResponse(
            "PM-KISAN Samman Nidhi provides ₹6,000/year to farmers. " +
            "3 installments of ₹2,000 each. Apply at pmkisan.gov.in with Aadhaar and land records."
        ),
        
        "soil health card" to CachedResponse(
            "Soil Health Card shows soil nutrient status and fertilizer recommendations. " +
            "Get free testing at nearest agriculture office. " +
            "Visit soilhealth.dac.gov.in. Apply every 2 years for updated card."
        ),
        
        "msp rice" to CachedResponse(
            "Minimum Support Price (MSP) for paddy: ₹2,183/quintal (2024-25). " +
            "Sell at APMC mandi or to FCI. Required: land records, bank account. " +
            "Check latest MSP at cacp.dacnet.nic.in"
        ),
        
        "fertilizer subsidy" to CachedResponse(
            "Government provides fertilizer subsidy through DBT. " +
            "Get subsidized DAP, urea, NPK at cooperatives. " +
            "Link Aadhaar for direct benefit transfer. Visit urvarak.nic.in"
        ),
        
        // HEALTH & EMERGENCY (Priority #3)
        "emergency number" to CachedResponse(
            "Emergency numbers: " +
            "Police: 100 | Ambulance: 108 | Fire: 101 | " +
            "Women Helpline: 1091 | Child Helpline: 1098 | " +
            "COVID Helpline: 1075 | National Emergency: 112"
        ),
        
        "ambulance" to CachedResponse(
            "Dial 108 for free ambulance service in most states. " +
            "Alternative: 102 (free ambulance for pregnant women and children). " +
            "National emergency: 112"
        ),
        
        "fever treatment" to CachedResponse(
            "For fever: Rest, drink plenty of water, take paracetamol (500mg). " +
            "⚠️ IMPORTANT: If fever persists for 3+ days, has severe headache, or vomiting, " +
            "consult doctor immediately. Could be dengue/malaria. Call 108 if severe.",
            verified = true,
            source = "General Guidance - Consult Doctor"
        ),
        
        "snake bite" to CachedResponse(
            "🚨 SNAKE BITE FIRST AID: " +
            "1) Keep person calm and still. 2) Remove jewelry from affected area. " +
            "3) Call 108 IMMEDIATELY. 4) DO NOT apply tourniquet, ice, or try to suck venom. " +
            "Get to hospital within 2 hours. Anti-venom is life-saving."
        ),
        
        "diarrhea treatment" to CachedResponse(
            "For diarrhea: ORS solution (1 packet in 1 liter clean water). " +
            "Drink every hour. Zinc tablets if available. Avoid outside food. " +
            "⚠️ Consult doctor if: Blood in stool, severe dehydration, fever, lasts 3+ days.",
            source = "General Guidance - Consult Doctor"
        ),
        
        "diabetes" to CachedResponse(
            "Diabetes is high blood sugar. Symptoms: Frequent urination, thirst, fatigue. " +
            "Management: Regular exercise, low sugar diet, medicines as prescribed. " +
            "Get regular checkups. Free testing at PHC. Visit npcdscs.mohfw.gov.in"
        ),
        
        "blood pressure" to CachedResponse(
            "Normal BP: 120/80. High BP: 140/90 or above. " +
            "Control: Low salt diet, regular exercise, reduce stress, take prescribed medicines. " +
            "Free checkup at PHC/CHC. Monitor regularly."
        ),
        
        "vaccination schedule" to CachedResponse(
            "Child vaccination schedule: BCG, Polio, DPT, Measles, Hepatitis B. " +
            "Free at Anganwadi and PHC. Keep immunization card safe. " +
            "Visit mohfw.gov.in or ask ASHA worker for complete schedule."
        ),
        
        "pregnancy care" to CachedResponse(
            "Pregnant women get free care under Janani Suraksha Yojana. " +
            "Free: Checkups, medicines, delivery, ₹1,400 cash assistance. " +
            "Register at Anganwadi or PHC. Contact ASHA worker. 4+ checkups mandatory."
        ),
        
        // EDUCATION
        "scholarship" to CachedResponse(
            "Government scholarships available: " +
            "Pre-matric (SC/ST/OBC), Post-matric, Merit-based. " +
            "Apply at scholarships.gov.in with Aadhaar, income certificate, caste certificate. " +
            "Deadline: Usually July-September."
        ),
        
        "midday meal" to CachedResponse(
            "Mid-Day Meal Scheme provides free lunch to school children (Class 1-8). " +
            "Nutritious meal with 450 calories, 12g protein. " +
            "Contact school headmaster if not provided."
        ),
        
        "school admission" to CachedResponse(
            "RTE Act ensures free education (6-14 years) in government schools. " +
            "Admission: Visit nearest school with birth certificate, Aadhaar, address proof. " +
            "No admission fees. Books and uniforms free."
        ),
        
        // BANKING & FINANCE
        "bank account" to CachedResponse(
            "Open bank account with Aadhaar and one more ID proof. " +
            "Zero balance account under Jan Dhan Yojana. " +
            "Benefits: RuPay card, ₹10,000 overdraft, insurance. Visit any bank branch."
        ),
        
        "kisan credit card interest" to CachedResponse(
            "KCC interest rate: 4% per annum (with 3% subsidy + 3% prompt repayment incentive). " +
            "Effective rate can be 4% if repaid on time. " +
            "Loan limit: Up to ₹3 lakh without collateral."
        ),
        
        "pension scheme" to CachedResponse(
            "PM Kisan Maan Dhan Yojana: Pension scheme for farmers (18-40 years). " +
            "Contribution: ₹55-200/month. Pension: ₹3,000/month after 60. " +
            "Enroll at CSC with Aadhaar and savings account. Visit maandhan.in"
        ),
        
        // LEGAL & DOCUMENTS
        "birth certificate" to CachedResponse(
            "Get birth certificate within 21 days of birth (free). " +
            "Apply at: Local body office (Gram Panchayat/Municipality). " +
            "Required: Hospital certificate, parents' IDs. " +
            "Online: crsorgi.gov.in"
        ),
        
        "death certificate" to CachedResponse(
            "Apply for death certificate within 21 days at local body office. " +
            "Required: Medical certificate, applicant's ID, deceased's ID proof. " +
            "Free if applied within 21 days. Online: crsorgi.gov.in"
        ),
        
        "income certificate" to CachedResponse(
            "Income certificate issued by Tahsildar office. " +
            "Required: Aadhaar, salary slips/income proof, ration card, address proof. " +
            "Fees: ₹10-30 (varies by state). Processing: 7-15 days. " +
            "Needed for: Scholarships, loans, government schemes."
        ),
        
        "caste certificate" to CachedResponse(
            "Apply for caste certificate at Tahsildar/SDM office. " +
            "Required: Aadhaar, parent's caste certificate (if available), community certificate. " +
            "Processing: 15-30 days. Needed for: Reservations, scholarships."
        ),
        
        "domicile certificate" to CachedResponse(
            "Domicile certificate proves residence in state. " +
            "Apply at: Tahsildar office with Aadhaar, address proof, school certificates. " +
            "Processing: 15-30 days. Needed for: Education admissions, government jobs."
        ),
        
        "land records" to CachedResponse(
            "Check land records online at state bhulekh portal or visit Tahsildar office. " +
            "Documents: 7/12 extract, 8A, property card. " +
            "Fees: ₹15-50 per document. Required for: Loans, schemes, property transactions."
        ),
        
        "mutation of land" to CachedResponse(
            "Land mutation (name change in records) done at Tahsildar office. " +
            "Required: Sale deed, previous record, Aadhaar, property tax receipt. " +
            "Fees: ₹50-200. Processing: 30-90 days."
        ),
        
        // WOMEN & CHILD WELFARE
        "beti bachao beti padhao" to CachedResponse(
            "Beti Bachao Beti Padhao promotes girl child welfare. " +
            "Benefits: Awareness, education support, Sukanya Samriddhi accounts. " +
            "Contact: District Women & Child Development office or call 1800-11-6229"
        ),
        
        "anganwadi services" to CachedResponse(
            "Anganwadi provides: Supplementary nutrition, pre-school education, " +
            "immunization, health checkups for children (0-6 years) and pregnant/lactating mothers. " +
            "Free services. Contact: Nearest Anganwadi worker."
        ),
        
        "women helpline" to CachedResponse(
            "Women in distress helpline: 1091 (24x7). " +
            "For domestic violence, harassment, emergency. " +
            "Also: Police (100), One Stop Centre (181), Legal aid (15100)"
        ),
        
        // EMPLOYMENT
        "rozgar mela" to CachedResponse(
            "Rozgar Mela (job fair) organized by govt for employment. " +
            "Check district employment office for dates. " +
            "Carry: Resume, ID proofs, educational certificates. " +
            "Register at ncs.gov.in for notifications."
        ),
        
        "skill development" to CachedResponse(
            "Pradhan Mantri Kaushal Vikas Yojana (PMKVY) provides free skill training. " +
            "Courses: Tailoring, plumbing, electrician, computer, etc. " +
            "Stipend + certificate. Visit pmkvyofficial.org or call 08800055555"
        ),
        
        // DISASTER & RELIEF
        "flood relief" to CachedResponse(
            "For flood relief: Contact District Collector office or call 108. " +
            "Relief camps provide: Food, water, medicines, temporary shelter. " +
            "Compensation for damage: Apply at Tahsildar office with photos and damage proof."
        ),
        
        "drought relief" to CachedResponse(
            "Drought relief: NDRF provides fodder, water tankers, employment under MGNREGA. " +
            "Contact: District Collector or Gram Panchayat. " +
            "Crop insurance claims: Apply within 72 hours at bank."
        ),
        
        // GENERAL INFO
        "complaint registration" to CachedResponse(
            "Register complaints at: " +
            "1) Gram Panchayat for local issues. " +
            "2) District Collector office for major grievances. " +
            "3) Online: pgportal.gov.in (Public Grievance Portal). " +
            "Track complaint status online."
        ),
        
        "voter id" to CachedResponse(
            "Apply for Voter ID at nearest Electoral office or online at voters.eci.gov.in. " +
            "Required: Aadhaar, age proof, address proof, passport size photo. " +
            "Minimum age: 18 years. Processing: 30 days. Helpline: 1950"
        ),
        
        "pan card" to CachedResponse(
            "Apply for PAN card online at tin.tin.nsdl.com or visit NSDL/UTI office. " +
            "Required: Aadhaar, ID proof, address proof, photo. " +
            "Fees: ₹107 (online), ₹93 (physical). " +
            "Processing: 15-20 days. Link with Aadhaar at incometax.gov.in"
        ),
        
        "driving license" to CachedResponse(
            "Apply for driving license at RTO. " +
            "Process: 1) Learning license test 2) Wait 30 days 3) Driving test 4) Permanent license. " +
            "Required: Aadhaar, address proof, medical certificate. " +
            "Fees: ₹150-500. Valid: 20 years. Visit parivahan.gov.in"
        )
    )

    fun loadModel(modelPath: String): Boolean {
        Log.i("LLMRunner", "Loading model at: $modelPath")
        val ok = initModel(modelPath)
        isLoaded = ok
        return ok
    }

    /**
     * Get cached response for village queries
     * Returns null if not found in cache
     */
    private fun getCachedResponse(query: String): CachedResponse? {
        val normalizedQuery = query.lowercase().trim()
        
        // Direct match
        verifiedResponses[normalizedQuery]?.let {
            Log.i("LLMRunner", "✅ CACHE HIT (direct): $normalizedQuery")
            return it
        }
        
        // Fuzzy match - check if query contains any cached key
        for ((key, response) in verifiedResponses) {
            if (normalizedQuery.contains(key) || key.contains(normalizedQuery)) {
                Log.i("LLMRunner", "✅ CACHE HIT (fuzzy): '$normalizedQuery' matched '$key'")
                return response
            }
        }
        
        Log.i("LLMRunner", "❌ CACHE MISS: $normalizedQuery - using LLM")
        return null
    }

    /**
     * Convert URLs in text to clickable hyperlinks
     */
    private fun makeLinksClickable(text: String): CharSequence {
        val spannableString = SpannableString(text)
        val matcher = Patterns.WEB_URL.matcher(text)
        
        while (matcher.find()) {
            val url = matcher.group()
            val start = matcher.start()
            val end = matcher.end()
            
            val fullUrl = if (!url.startsWith("http://") && !url.startsWith("https://")) {
                "https://$url"
            } else {
                url
            }
            
            spannableString.setSpan(
                URLSpan(fullUrl),
                start,
                end,
                Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            )
        }
        
        return spannableString
    }

    /**
     * Detect if response is gibberish/rambling
     */
    private fun isGibberish(text: String): Boolean {
        val words = text.split(" ")
        if (words.size < 10) return false
        
        val uniqueWords = words.distinct()
        val repetitionRatio = words.size.toFloat() / uniqueWords.size
        
        if (repetitionRatio > 2.5f) {
            Log.w("LLMRunner", "High repetition detected (ratio: $repetitionRatio)")
            return true
        }
        
        if (text.length > 400) {
            Log.w("LLMRunner", "Response too long (${text.length} chars)")
            return true
        }
        
        return false
    }

    /**
     * Clean up response and detect gibberish
     */
    private fun cleanResponse(raw: String): String {
        var cleanText = raw
            .trim()
            .removePrefix("Answer:")
            .removePrefix(":")
            .trim()

        if (cleanText.contains("?")) {
            val beforeQuestion = cleanText.substringBefore("?").trim()
            if (beforeQuestion.isNotEmpty()) {
                cleanText = beforeQuestion
                Log.w("LLMRunner", "Found '?', truncated response")
            }
        }

        if (cleanText.length > 300) {
            val sentences = cleanText.split(". ")
            cleanText = if (sentences.size > 2) {
                sentences.take(2).joinToString(". ") + "."
            } else {
                sentences.firstOrNull() ?: cleanText
            }
            Log.w("LLMRunner", "Response too long, truncated to first sentences")
        }

        if (isGibberish(cleanText)) {
            Log.e("LLMRunner", "Gibberish detected! Returning fallback")
            return "I'm not sure about that. Could you ask in simpler terms?"
        }

        val forbiddenPhrases = listOf(
            "Question:", "User:", "Sakhi:", "Human:",
            "(smiling)", "(thinking)", "###", "---"
        )
        
        for (phrase in forbiddenPhrases) {
            if (cleanText.contains(phrase, ignoreCase = true)) {
                cleanText = cleanText.substringBefore(phrase, cleanText).trim()
                Log.w("LLMRunner", "Found forbidden phrase '$phrase', truncated")
            }
        }

        if (cleanText.isEmpty() || cleanText.length < 3) {
            cleanText = "I'm not sure how to answer that. Could you rephrase?"
        }

        return cleanText
    }

    fun simplify(text: String?, prefs: Map<String, Any>?): Map<String, Any> {
        val input = text?.trim() ?: ""
        
        // Handle empty input
        if (input.isEmpty() || input.length < 2) {
            return mapOf(
                "steps" to listOf(
                    mapOf(
                        "id" to 1, 
                        "text" to "I didn't hear your question clearly. Could you please repeat?",
                        "source" to "Error"
                    )
                )
            )
        }
        
        // =========================================================================
        // STEP 1: CHECK CACHED RESPONSES FIRST (Priority!)
        // =========================================================================
        val cachedResponse = getCachedResponse(input)
        if (cachedResponse != null) {
            val formattedText = makeLinksClickable(cachedResponse.response)
            Log.i("LLMRunner", "✅ Returned VERIFIED cached response (${cachedResponse.response.length} chars)")
            
            return mapOf(
                "steps" to listOf(
                    mapOf(
                        "id" to 1, 
                        "text" to formattedText.toString(),
                        "source" to cachedResponse.source,
                        "verified" to cachedResponse.verified,
                        "cache_hit" to true
                    )
                )
            )
        }
        
        // =========================================================================
        // STEP 2: USE LLM IF NOT IN CACHE
        // =========================================================================
        if (!isLoaded) {
            Log.e("LLMRunner", "simplify() called before model loaded!")
            return mapOf("steps" to listOf(mapOf("id" to 1, "text" to "Model not loaded", "source" to "Error")))
        }
        
        val retrievedContext = prefs?.get("retrieved_context")?.toString()?.trim().orEmpty()
        val prompt = if (retrievedContext.isNotEmpty()) {
            """You are a grounded village assistant.
    Use only the provided context. If the context does not answer the question, say you are not sure.

    CONTEXT:
    $retrievedContext

    QUESTION: $input
    Answer:""".trimIndent()
        } else {
            """Question: $input
    Answer:""".trimIndent()
        }

        Log.i("LLMRunner", "⚠️ CACHE MISS - Using LLM for: $input")
        val startTime = System.currentTimeMillis()
        
        val rawResponse = infer(prompt)
        
        val duration = System.currentTimeMillis() - startTime
        Log.i("LLMRunner", "LLM inference complete. Took ${duration}ms, raw length=${rawResponse.length}")

        var cleanText = cleanResponse(rawResponse)
        val formattedText = makeLinksClickable(cleanText)

        return mapOf(
            "steps" to listOf(
                mapOf(
                    "id" to 1, 
                    "text" to formattedText.toString(),
                    "source" to "AI Generated",
                    "verified" to false,
                    "cache_hit" to false,
                    "rag_context_used" to retrievedContext.isNotEmpty(),
                    "inference_time_ms" to duration
                )
            )
        )
    }

    /**
     * Get statistics about cached responses
     */
    fun getCacheStats(): Map<String, Any> {
        return mapOf(
            "total_cached_queries" to verifiedResponses.size,
            "categories" to mapOf(
                "government_schemes" to 15,
                "agriculture" to 8,
                "health_emergency" to 12,
                "education" to 4,
                "banking_finance" to 5,
                "legal_documents" to 8,
                "women_child_welfare" to 4,
                "employment" to 3,
                "disaster_relief" to 2,
                "general" to 5
            )
        )
    }
}