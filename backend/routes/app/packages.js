const express = require('express');
const router = express.Router();
const Package = require('../../models/Package');
const Lab = require('../../models/Lab');
const { optionalAuth } = require('../../middleware/auth');

router.use(optionalAuth);

/**
 * GET /api/app/packages
 * Browse active packages across all labs, with search/category filter and
 * pagination.
 */
router.get('/', async (req, res) => {
    try {
        const { search, category, city, labId, page = 1, limit = 20 } = req.query;

        const filter = { isActive: true };
        if (category) {
            filter.category = category;
        }
        if (search) {
            filter.$or = [
                { name: { $regex: search, $options: 'i' } },
                { nameAr: { $regex: search, $options: 'i' } },
            ];
        }
        if (labId) {
            filter.labId = labId;
        } else if (city) {
            // Restrict to packages sold by labs in the patient's own governorate
            const cityLabIds = await Lab.find({ city, status: 'Active' }).distinct('_id');
            filter.labId = { $in: cityLabIds };
        }

        const pageNum = Math.max(1, parseInt(page, 10) || 1);
        const limitNum = Math.min(50, Math.max(1, parseInt(limit, 10) || 20));

        const [packages, total, labIds] = await Promise.all([
            Package.find(filter)
                .populate('labId', 'name city logo averageRating status')
                .sort({ isMostRequested: -1, createdAt: -1 })
                .skip((pageNum - 1) * limitNum)
                .limit(limitNum),
            Package.countDocuments(filter),
            Package.distinct('labId', filter),
        ]);

        // Only show packages from labs that are still active.
        const activePackages = packages.filter((p) => p.labId && p.labId.status === 'Active');

        res.json({
            success: true,
            data: {
                packages: activePackages.map((p) => ({
                    _id: p._id,
                    name: p.name,
                    nameAr: p.nameAr,
                    nameKu: p.nameKu,
                    category: p.category,
                    testCount: p.testIds.length,
                    price: p.price,
                    icon: p.icon,
                    isMostRequested: p.isMostRequested,
                    lab: {
                        _id: p.labId._id,
                        name: p.labId.name,
                        city: p.labId.city,
                        logo: p.labId.logo,
                        averageRating: p.labId.averageRating,
                    },
                })),
                pagination: {
                    total,
                    page: pageNum,
                    limit: limitNum,
                    pages: Math.ceil(total / limitNum) || 1,
                },
                labCount: labIds.length,
            },
        });
    } catch (error) {
        console.error('Get packages error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

/**
 * GET /api/app/packages/:id
 * Single package detail, with its constituent tests resolved to name/price.
 */
router.get('/:id', async (req, res) => {
    try {
        const pkg = await Package.findOne({ _id: req.params.id, isActive: true })
            .populate('labId', 'name city logo averageRating totalRatings address status');

        if (!pkg || !pkg.labId || pkg.labId.status !== 'Active') {
            return res.status(404).json({ success: false, message: 'Package not found' });
        }

        const lab = await Lab.findById(pkg.labId._id).select('tests');
        const testIdSet = new Set(pkg.testIds.map((id) => String(id)));
        const tests = (lab?.tests || [])
            .filter((t) => testIdSet.has(String(t._id)))
            .map((t) => ({ _id: t._id, name: t.name, nameAr: t.nameAr, price: t.price }));

        res.json({
            success: true,
            data: {
                package: {
                    _id: pkg._id,
                    name: pkg.name,
                    nameAr: pkg.nameAr,
                    nameKu: pkg.nameKu,
                    description: pkg.description,
                    descriptionAr: pkg.descriptionAr,
                    category: pkg.category,
                    price: pkg.price,
                    icon: pkg.icon,
                    isMostRequested: pkg.isMostRequested,
                    tests,
                    lab: pkg.labId,
                },
            },
        });
    } catch (error) {
        console.error('Get package details error:', error);
        res.status(500).json({ success: false, message: 'Server error' });
    }
});

module.exports = router;
